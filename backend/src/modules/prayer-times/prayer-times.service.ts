import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { RamadanDayScheduleDto, UpdatePrayerTimeDto, UpdatePrayerTimeRangeDto } from './dto/prayer-time.dto';

@Injectable()
export class PrayerTimesService {
  constructor(private prisma: PrismaService) {}

  async getTodayTimes(masjidId: string, dateStr?: string) {
    const targetDate = dateStr
      ? new Date(`${dateStr}T00:00:00.000Z`)
      : new Date(new Date().toISOString().slice(0, 10) + 'T00:00:00.000Z');

    const times = await this.prisma.prayerTime.findUnique({
      where: {
        idx_prayer_times_unique: {
          masjidId,
          date: targetDate,
        },
      },
    });

    const period = await this.findApplicablePeriod(masjidId, targetDate);
    if (!times) return period ? { ...period, date: targetDate } : null;
    if (period && period.updatedAt > times.updatedAt) {
      return { ...period, date: targetDate };
    }
    return times;
  }

  async getMonthSchedule(masjidId: string, year: number, month: number) {
    const startDate = new Date(Date.UTC(year, month - 1, 1));
    const endDate = new Date(Date.UTC(year, month, 0));
    const [savedRows, periods] = await Promise.all([
      this.prisma.prayerTime.findMany({
      where: {
        masjidId,
        date: {
          gte: startDate,
          lte: endDate,
        },
      },
      orderBy: { date: 'asc' },
      }),
      this.prisma.prayerSchedulePeriod.findMany({
        where: {
          masjidId,
          startDate: { lte: endDate },
          OR: [{ endDate: null }, { endDate: { gte: startDate } }],
        },
        orderBy: { startDate: 'asc' },
      }),
    ]);
    const byDate = new Map(savedRows.map((row) => [this.dateKey(row.date), row]));
    for (let date = new Date(startDate); date <= endDate; date.setUTCDate(date.getUTCDate() + 1)) {
      const key = this.dateKey(date);
      const period = periods
        .filter((item) => item.startDate <= date && (!item.endDate || item.endDate >= date))
        .at(-1);
      const saved = byDate.get(key);
      if (period && (!saved || period.updatedAt > saved.updatedAt)) {
        byDate.set(key, { ...period, id: `${period.id}:${key}`, date } as any);
      }
    }
    return Array.from(byDate.values()).sort((a, b) => a.date.getTime() - b.date.getTime());
  }

  private dateKey(date: Date) { return date.toISOString().slice(0, 10); }

  private async findApplicablePeriod(masjidId: string, date: Date) {
    return this.prisma.prayerSchedulePeriod.findFirst({
      where: { masjidId, startDate: { lte: date }, OR: [{ endDate: null }, { endDate: { gte: date } }] },
      orderBy: { startDate: 'desc' },
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
    const end = dto.endDate ? new Date(`${dto.endDate}T00:00:00.000Z`) : null;
    const dayCount = end ? Math.floor((end.getTime() - start.getTime()) / 86400000) + 1 : 1;
    if (!Number.isFinite(dayCount) || dayCount < 1 || dayCount > 366) {
      throw new BadRequestException('Choose a valid date range of up to 366 days.');
    }
    const requiredTimes = [dto.fajrJamaah, dto.dhuhrJamaah, dto.asrJamaah, dto.maghribJamaah, dto.ishaJamaah];
    if (requiredTimes.some((time) => !time)) {
      throw new BadRequestException('Enter Jamaah times for all five daily prayers.');
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

    await this.prisma.$transaction(async (tx) => {
      // A newer open-ended timetable closes the previous open period the day
      // before it starts, preserving a clear, queryable schedule history.
      await tx.prayerSchedulePeriod.updateMany({
        where: { masjidId, endDate: null, startDate: { lt: start } },
        data: { endDate: new Date(start.getTime() - 86400000) },
      });
      await tx.prayerSchedulePeriod.create({
        data: {
          masjidId,
          startDate: start,
          endDate: end,
          updatedBy: userId,
          ...prayerFields,
        },
      });
    });
    return {
      success: true,
      count: end ? dayCount : 1,
      startDate: dto.startDate,
      endDate: dto.endDate ?? null,
      appliesUntilChanged: !dto.endDate,
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
    const applicablePeriod = await this.findApplicablePeriod(masjidId, date);
    const base = existing ?? applicablePeriod;

    const requiredJamaahTimes = [
      dto.fajrJamaah ?? base?.fajrJamaah,
      dto.dhuhrJamaah ?? base?.dhuhrJamaah,
      dto.asrJamaah ?? base?.asrJamaah,
      dto.maghribJamaah ?? base?.maghribJamaah,
      dto.ishaJamaah ?? base?.ishaJamaah,
    ];
    if (requiredJamaahTimes.some((time) => !time?.trim())) {
      throw new BadRequestException(
        'Enter Jamaah times for Fajr, Dhuhr, Asr, Maghrib, and Isha.',
      );
    }

    const dataToSave = {
      fajrAdhan: dto.fajrAdhan !== undefined ? dto.fajrAdhan : base?.fajrAdhan,
      fajrJamaah: dto.fajrJamaah || base?.fajrJamaah,
      sunrise: dto.sunrise !== undefined ? dto.sunrise : base?.sunrise,
      dhuhrAdhan: dto.dhuhrAdhan !== undefined ? dto.dhuhrAdhan : base?.dhuhrAdhan,
      dhuhrJamaah: dto.dhuhrJamaah || base?.dhuhrJamaah,
      asrAdhan: dto.asrAdhan !== undefined ? dto.asrAdhan : base?.asrAdhan,
      asrJamaah: dto.asrJamaah || base?.asrJamaah,
      sunset: dto.sunset !== undefined ? dto.sunset : base?.sunset,
      maghribAdhan: dto.maghribAdhan !== undefined ? dto.maghribAdhan : base?.maghribAdhan,
      maghribJamaah: dto.maghribJamaah || base?.maghribJamaah,
      ishaAdhan: dto.ishaAdhan !== undefined ? dto.ishaAdhan : base?.ishaAdhan,
      ishaJamaah: dto.ishaJamaah || base?.ishaJamaah,
      jummahKhutbah: dto.jummahKhutbah !== undefined ? dto.jummahKhutbah : base?.jummahKhutbah,
      jummahJamaah: dto.jummahJamaah !== undefined ? dto.jummahJamaah : base?.jummahJamaah,
    };

    if (!existing && applicablePeriod) {
      return this.prisma.prayerSchedulePeriod.update({
        where: { id: applicablePeriod.id },
        data: { ...dataToSave, updatedBy: userId },
      });
    }

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
