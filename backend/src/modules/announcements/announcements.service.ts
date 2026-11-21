import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { FirebaseService } from '../../common/firebase/firebase.service';
import { CreateAnnouncementDto, BroadcastAnnouncementDto } from './dto/announcement.dto';
import { AnnouncementCategory } from '@prisma/client';

@Injectable()
export class AnnouncementsService {
  private readonly logger = new Logger(AnnouncementsService.name);

  constructor(
    private prisma: PrismaService,
    private firebaseService: FirebaseService,
  ) {}

  async findByMasjid(masjidId: string) {
    return this.prisma.announcement.findMany({
      where: {
        masjidId,
        publishedAt: { lte: new Date() },
        OR: [
          { expiresAt: null },
          { expiresAt: { gt: new Date() } },
        ],
      },
      orderBy: [
        { isPinned: 'desc' },
        { publishedAt: 'desc' },
      ],
      include: {
        creator: { select: { id: true, name: true } },
      },
    });
  }

  async findBroadcasts() {
    return this.prisma.announcement.findMany({
      where: {
        masjidId: null,
      },
      orderBy: { createdAt: 'desc' },
      include: {
        creator: { select: { id: true, name: true } },
      },
    });
  }

  async createBroadcast(userId: string, dto: BroadcastAnnouncementDto) {
    const announcement = await this.prisma.announcement.create({
      data: {
        title: dto.title,
        titleTa: dto.titleTa,
        body: dto.body,
        bodyTa: dto.bodyTa,
        category: AnnouncementCategory.GENERAL,
        createdBy: userId,
        publishedAt: new Date(),
        notifyPush: dto.notifyPush ?? true,
      } as any,
    });

    let recipientCount = 0;

    if (dto.notifyPush ?? true) {
      try {
        const audience = (dto.targetAudience || 'ALL').toUpperCase();
        let targetUserIds: string[] | undefined;

        if (audience.includes('ADMIN')) {
          const admins = await this.prisma.masjidAdmin.findMany({
            select: { userId: true },
            distinct: ['userId'],
          });
          targetUserIds = admins.map((a) => a.userId);
        } else if (audience.includes('MUSALLI')) {
          const admins = await this.prisma.masjidAdmin.findMany({
            select: { userId: true },
            distinct: ['userId'],
          });
          const adminIds = new Set(admins.map((a) => a.userId));
          const allUsers = await this.prisma.user.findMany({
            select: { id: true },
          });
          targetUserIds = allUsers.filter((u) => !adminIds.has(u.id)).map((u) => u.id);
        }

        const deviceWhere: any = { isActive: true };
        if (targetUserIds) {
          deviceWhere.userId = { in: targetUserIds };
        }

        const devices = await this.prisma.device.findMany({
          where: deviceWhere,
          select: { fcmToken: true },
        });

        const tokens = devices.map((d) => d.fcmToken);
        recipientCount = tokens.length;

        if (tokens.length > 0) {
          await this.firebaseService.sendPushNotification(
            tokens,
            dto.title,
            dto.body,
            {
              type: 'BROADCAST',
              id: announcement.id,
              audience: dto.targetAudience || 'ALL',
            },
          );
        }
      } catch (err) {
        this.logger.error(`Failed to dispatch broadcast FCM notification: ${err}`);
      }
    }

    return {
      ...announcement,
      recipientCount,
      targetAudience: dto.targetAudience || 'All Users',
    };
  }

  async create(masjidId: string, userId: string, dto: CreateAnnouncementDto) {
    const announcement = await this.prisma.announcement.create({
      data: {
        ...dto,
        masjidId,
        createdBy: userId,
        publishedAt: new Date(),
      } as any,
    });

    if (dto.notifyPush) {
      try {
        // Find followers/members of this masjid
        const members = await this.prisma.membership.findMany({
          where: { masjidId },
          select: { userId: true },
        });

        const userIds = members.map((m) => m.userId);
        if (userIds.length > 0) {
          const devices = await this.prisma.device.findMany({
            where: {
              userId: { in: userIds },
              isActive: true,
            },
            select: { fcmToken: true },
          });

          const tokens = devices.map((d) => d.fcmToken);
          if (tokens.length > 0) {
            await this.firebaseService.sendPushNotification(
              tokens,
              dto.title,
              dto.body,
              {
                type: 'MASJID_NOTICE',
                masjidId,
                id: announcement.id,
              },
            );
          }
        }
      } catch (err) {
        this.logger.error(`Failed to dispatch masjid notice FCM: ${err}`);
      }
    }

    return announcement;
  }

  async delete(masjidId: string, id: string) {
    return this.prisma.announcement.deleteMany({
      where: { id, masjidId },
    });
  }

  async deleteBroadcast(id: string) {
    return this.prisma.announcement.delete({
      where: { id },
    });
  }
}
