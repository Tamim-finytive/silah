import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RamadanDayScheduleDto, UpdatePrayerTimeDto, UpdatePrayerTimeRangeDto } from './dto/prayer-time.dto';

@Injectable()
export class PrayerTimesService {
  constructor(private prisma: PrismaService) {}

  async getTodayTimes(masjidId: string, dateStr?: string) {
    const targetDate = dateStr ? new Date(dateStr) : new Date();
    targetDate.setHours(0, 0, 0, 0);

    const times = await this.prisma.prayerTime.findUnique({
      where: {
        idx_prayer_times_unique: {
          masjidId,
          date: targetDate,
        },
      },
    });

    if (!times) {
      // A masjid schedule is date-specific. Never present another day's
      // timings as today's schedule; an absent row means the admin must create it.
      return null;
    }

    return times;
  }

  async getMonthSchedule(masjidId: string, year: number, month: number) {
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0);

    return this.prisma.prayerTime.findMany({
      where: {
        masjidId,
        date: {
          gte: startDate,
          lte: endDate,
        },
      },
      orderBy: { date: 'asc' },
    });
  }

  async getRamadanMonth(masjidId: string, year: number, month: number) {
    const startDate = new Date(Date.UTC(year, month - 1, 1));
    const endDate = new Date(Date.UTC(year, month, 0));
    return this.prisma.ramadanDaySchedule.findMany({
      where: { masjidId, date: { gte: startDate, lte: endDate } },
      orderBy: { date: 'asc' },
    });
  }

  async upsertRamadanDays(
    masjidId: string,
    userId: string,
    days: RamadanDayScheduleDto[],
  ) {
    const uniqueDays = new Map(days.map((day) => [day.date, day]));
    return this.prisma.$transaction(
      Array.from(uniqueDays.values()).map((day) => {
        const date = new Date(`${day.date}T00:00:00.000Z`);
        return this.prisma.ramadanDaySchedule.upsert({
          where: {
            idx_ramadan_day_schedules_unique: { masjidId, date },
          },
          update: {
            sehriEnd: day.sehriEnd,
            iftarTime: day.iftarTime,
            notes: day.notes,
          },
          create: {
            masjidId,
            date,
            sehriEnd: day.sehriEnd,
            iftarTime: day.iftarTime,
            notes: day.notes,
            createdBy: userId,
          },
        });
      }),
    );
  }

  async upsertPrayerTimeRange(
    masjidId: string,
    userId: string,
    dto: UpdatePrayerTimeRangeDto,
  ) {
    const start = new Date(`${dto.startDate}T00:00:00.000Z`);
    const end = new Date(`${dto.endDate}T00:00:00.000Z`);
    const dayCount = Math.floor((end.getTime() - start.getTime()) / 86400000) + 1;
    if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 31) {
      throw new BadRequestException('Choose a valid range of 1 to 31 dates.');
    }

    const days: Date[] = [];
    for (let offset = 0; offset < dayCount; offset += 1) {
      const date = new Date(start);
      date.setUTCDate(start.getUTCDate() + offset);
      days.push(date);
    }

    const prayerFields = {
      sunrise: dto.sunrise,
      sunset: dto.sunset,
      fajrAdhan: dto.fajrAdhan,
      fajrJamaah: dto.fajrJamaah,
      dhuhrAdhan: dto.dhuhrAdhan,
      dhuhrJamaah: dto.dhuhrJamaah,
      asrAdhan: dto.asrAdhan,
      asrJamaah: dto.asrJamaah,
      maghribAdhan: dto.maghribAdhan,
      maghribJamaah: dto.maghribJamaah,
      ishaAdhan: dto.ishaAdhan,
      ishaJamaah: dto.ishaJamaah,
      jummahKhutbah: dto.jummahKhutbah,
      jummahJamaah: dto.jummahJamaah,
    };

    const operations = days.map((date) =>
      this.prisma.prayerTime.upsert({
        where: { idx_prayer_times_unique: { masjidId, date } },
        update: { ...prayerFields, date, updatedBy: userId },
        create: { ...prayerFields, masjidId, date, updatedBy: userId },
      }),
    );
    const saved = await this.prisma.$transaction(operations);
    return {
      success: true,
      count: saved.length,
      startDate: dto.startDate,
      endDate: dto.endDate,
    };
  }

  async upsertPrayerTime(masjidId: string, userId: string, dto: UpdatePrayerTimeDto) {
    const date = new Date(dto.date);
    date.setHours(0, 0, 0, 0);

    const existing = await this.prisma.prayerTime.findUnique({
      where: {
        idx_prayer_times_unique: {
          masjidId,
          date,
        },
      },
    });

    const requiredJamaahTimes = [
      dto.fajrJamaah ?? existing?.fajrJamaah,
      dto.dhuhrJamaah ?? existing?.dhuhrJamaah,
      dto.asrJamaah ?? existing?.asrJamaah,
      dto.maghribJamaah ?? existing?.maghribJamaah,
      dto.ishaJamaah ?? existing?.ishaJamaah,
    ];
    if (requiredJamaahTimes.some((time) => !time?.trim())) {
      throw new BadRequestException(
        'Enter Jamaah times for Fajr, Dhuhr, Asr, Maghrib, and Isha.',
      );
    }

    const dataToSave = {
      fajrAdhan: dto.fajrAdhan !== undefined ? dto.fajrAdhan : existing?.fajrAdhan,
      fajrJamaah: dto.fajrJamaah || existing?.fajrJamaah,
      sunrise: dto.sunrise !== undefined ? dto.sunrise : existing?.sunrise,
      dhuhrAdhan: dto.dhuhrAdhan !== undefined ? dto.dhuhrAdhan : existing?.dhuhrAdhan,
      dhuhrJamaah: dto.dhuhrJamaah || existing?.dhuhrJamaah,
      asrAdhan: dto.asrAdhan !== undefined ? dto.asrAdhan : existing?.asrAdhan,
      asrJamaah: dto.asrJamaah || existing?.asrJamaah,
      sunset: dto.sunset !== undefined ? dto.sunset : existing?.sunset,
      maghribAdhan: dto.maghribAdhan !== undefined ? dto.maghribAdhan : existing?.maghribAdhan,
      maghribJamaah: dto.maghribJamaah || existing?.maghribJamaah,
      ishaAdhan: dto.ishaAdhan !== undefined ? dto.ishaAdhan : existing?.ishaAdhan,
      ishaJamaah: dto.ishaJamaah || existing?.ishaJamaah,
      jummahKhutbah: dto.jummahKhutbah !== undefined ? dto.jummahKhutbah : existing?.jummahKhutbah,
      jummahJamaah: dto.jummahJamaah !== undefined ? dto.jummahJamaah : existing?.jummahJamaah,
    };

    return this.prisma.prayerTime.upsert({
      where: {
        idx_prayer_times_unique: {
          masjidId,
          date,
        },
      },
      update: {
        ...dataToSave,
        date,
        updatedBy: userId,
      },
      create: {
        ...dataToSave,
        fajrJamaah: dataToSave.fajrJamaah!,
        dhuhrJamaah: dataToSave.dhuhrJamaah!,
        asrJamaah: dataToSave.asrJamaah!,
        maghribJamaah: dataToSave.maghribJamaah!,
        ishaJamaah: dataToSave.ishaJamaah!,
        masjidId,
        date,
        updatedBy: userId,
      },
    });
  }
}
