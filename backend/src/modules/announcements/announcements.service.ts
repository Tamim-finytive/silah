import { Injectable, Logger, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { FirebaseService } from '../../common/firebase/firebase.service';
import { CreateAnnouncementDto, BroadcastAnnouncementDto, UpdateAnnouncementDto } from './dto/announcement.dto';
import { AnnouncementCategory } from '@prisma/client';

@Injectable()
export class AnnouncementsService {
  private readonly logger = new Logger(AnnouncementsService.name);

  constructor(
    private prisma: PrismaService,
    private firebaseService: FirebaseService,
  ) {}

  private async deactivateInvalidDeviceTokens(tokens: string[]) {
    if (tokens.length === 0) return;
    await this.prisma.device.updateMany({
      where: { fcmToken: { in: tokens } },
      data: { isActive: false },
    });
  }

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

  async findByMasjidWithReadCounts(masjidId: string) {
    const announcements = await this.findByMasjid(masjidId);
    return this.withReadCounts(announcements);
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

  async findBroadcastsWithReadCounts() {
    const announcements = await this.findBroadcasts();
    return this.withReadCounts(announcements);
  }

  private async withReadCounts(announcements: Array<{ id: string }>) {
    if (announcements.length === 0) return announcements;
    const counts = await this.prisma.announcementUserState.groupBy({
      by: ['announcementId'],
      where: {
        announcementId: { in: announcements.map((announcement) => announcement.id) },
        readAt: { not: null },
      },
      _count: { _all: true },
    });
    const countByAnnouncement = new Map(
      counts.map((entry) => [entry.announcementId, entry._count._all]),
    );
    return announcements.map((announcement) => ({
      ...announcement,
      readCount: countByAnnouncement.get(announcement.id) ?? 0,
    }));
  }

  async findForUser(
    userId: string,
    query: {
      status?: string;
      from?: string;
      to?: string;
      cursor?: string;
      limit?: number;
    },
  ) {
    const status = (query.status || 'ALL').toUpperCase();
    if (!['ALL', 'READ', 'UNREAD'].includes(status)) {
      throw new BadRequestException('Status must be ALL, READ, or UNREAD');
    }
    const pageSize = query.limit ?? 20;
    if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) {
      throw new BadRequestException('Limit must be an integer between 1 and 50');
    }
    const parseDate = (value: string | undefined, isEnd: boolean) => {
      if (!value) return undefined;
      const date = /^\d{4}-\d{2}-\d{2}$/.test(value)
        ? new Date(`${value}T${isEnd ? '23:59:59.999' : '00:00:00.000'}Z`)
        : new Date(value);
      if (Number.isNaN(date.getTime())) {
        throw new BadRequestException('Date filter is invalid');
      }
      return date;
    };
    const from = parseDate(query.from, false);
    const to = parseDate(query.to, true);
    if (from && to && from > to) {
      throw new BadRequestException('Start date must be before end date');
    }

    const memberships = await this.prisma.membership.findMany({
      where: { userId },
      select: { masjidId: true },
    });
    const masjidIds = memberships.map((membership) => membership.masjidId);
    const where: any = {
      publishedAt: { lte: new Date() },
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: new Date() } },
      ],
      AND: [
        { OR: masjidIds.length > 0
          ? [{ masjidId: null }, { masjidId: { in: masjidIds } }]
          : [{ masjidId: null }] },
        { NOT: { userStates: { some: { userId, hiddenAt: { not: null } } } } },
      ],
    };
    if (from || to) {
      where.publishedAt = {
        lte: to ?? new Date(),
        ...(from ? { gte: from } : {}),
      };
    }
    if (status === 'READ') {
      where.AND.push({
        userStates: { some: { userId, readAt: { not: null }, hiddenAt: null } },
      });
    } else if (status === 'UNREAD') {
      where.AND.push({
        userStates: { none: { userId, readAt: { not: null }, hiddenAt: null } },
      });
    }

    const announcements = await this.prisma.announcement.findMany({
      where,
      orderBy: [
        { publishedAt: 'desc' },
        { createdAt: 'desc' },
        { id: 'desc' },
      ],
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      take: pageSize + 1,
      include: {
        creator: { select: { id: true, name: true } },
        userStates: {
          where: { userId },
          select: { readAt: true },
          take: 1,
        },
      },
    });
    const hasMore = announcements.length > pageSize;
    const page = announcements.slice(0, pageSize);
    const items = page.map(({ userStates, ...announcement }) => ({
      ...announcement,
      isRead: userStates[0]?.readAt != null,
    }));
    return {
      items,
      nextCursor: hasMore ? page[page.length - 1]?.id ?? null : null,
      hasMore,
    };
  }

  private async ensureUserCanView(userId: string, announcementId: string) {
    const announcement = await this.prisma.announcement.findUnique({
      where: { id: announcementId },
      select: { id: true, masjidId: true, publishedAt: true, expiresAt: true },
    });
    if (!announcement ||
        (announcement.publishedAt && announcement.publishedAt > new Date()) ||
        (announcement.expiresAt && announcement.expiresAt <= new Date())) {
      throw new NotFoundException('Notice not found');
    }
    if (announcement.masjidId) {
      const membership = await this.prisma.membership.findUnique({
        where: {
          idx_memberships_unique: {
            userId,
            masjidId: announcement.masjidId,
          },
        },
        select: { id: true },
      });
      if (!membership) throw new NotFoundException('Notice not found');
    }
    return announcement;
  }

  async setReadState(userId: string, announcementId: string, isRead: boolean) {
    await this.ensureUserCanView(userId, announcementId);
    const readAt = isRead ? new Date() : null;
    return this.prisma.announcementUserState.upsert({
      where: { userId_announcementId: { userId, announcementId } },
      create: { userId, announcementId, readAt },
      update: { readAt },
      select: { announcementId: true, readAt: true, hiddenAt: true },
    });
  }

  async hideForUser(userId: string, announcementId: string) {
    await this.ensureUserCanView(userId, announcementId);
    return this.prisma.announcementUserState.upsert({
      where: { userId_announcementId: { userId, announcementId } },
      create: { userId, announcementId, hiddenAt: new Date() },
      update: { hiddenAt: new Date() },
      select: { announcementId: true, hiddenAt: true },
    });
  }

  async update(masjidId: string, announcementId: string, dto: UpdateAnnouncementDto) {
    const existing = await this.prisma.announcement.findFirst({
      where: { id: announcementId, masjidId },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('Notice not found for this masjid');
    const data: Record<string, unknown> = {};
    if (dto.category !== undefined) data.category = dto.category;
    if (dto.title !== undefined) data.title = dto.title;
    if (dto.titleTa !== undefined) data.titleTa = dto.titleTa;
    if (dto.body !== undefined) data.body = dto.body;
    if (dto.bodyTa !== undefined) data.bodyTa = dto.bodyTa;
    if (dto.isPinned !== undefined) data.isPinned = dto.isPinned;
    return this.prisma.announcement.update({
      where: { id: announcementId },
      data: data as any,
    });
  }

  async updateBroadcast(announcementId: string, dto: UpdateAnnouncementDto) {
    const existing = await this.prisma.announcement.findFirst({
      where: { id: announcementId, masjidId: null },
      select: { id: true },
    });
    if (!existing) throw new NotFoundException('Broadcast not found');
    const data: Record<string, unknown> = {};
    if (dto.title !== undefined) data.title = dto.title;
    if (dto.titleTa !== undefined) data.titleTa = dto.titleTa;
    if (dto.body !== undefined) data.body = dto.body;
    if (dto.bodyTa !== undefined) data.bodyTa = dto.bodyTa;
    return this.prisma.announcement.update({
      where: { id: announcementId },
      data: data as any,
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
          const delivery = await this.firebaseService.sendPushNotification(
            tokens,
            dto.title,
            dto.body,
            {
              type: 'BROADCAST',
              id: announcement.id,
              audience: dto.targetAudience || 'ALL',
            },
          );
          await this.deactivateInvalidDeviceTokens(delivery.invalidTokens);
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

    if (dto.notifyPush ?? true) {
      try {
        // Find followers/members of this masjid
        const members = await this.prisma.membership.findMany({
          where: { masjidId },
          select: { userId: true },
        });

        const userIds = [...new Set(members.map((m) => m.userId))];
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
            const delivery = await this.firebaseService.sendPushNotification(
              tokens,
              dto.title,
              dto.body,
              {
                type: 'MASJID_NOTICE',
                masjidId,
                id: announcement.id,
              },
            );
            await this.deactivateInvalidDeviceTokens(delivery.invalidTokens);
            this.logger.log(
              `Masjid notice ${announcement.id}: ${delivery.successCount}/${tokens.length} device deliveries succeeded (${userIds.length} member accounts targeted)`,
            );
          } else {
            this.logger.warn(
              `Masjid notice ${announcement.id}: no active registered device tokens for ${userIds.length} member accounts`,
            );
          }
        } else {
          this.logger.warn(
            `Masjid notice ${announcement.id}: no member accounts are connected to masjid ${masjidId}`,
          );
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
