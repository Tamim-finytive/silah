import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { CreateMasjidDto, AssignRoleDto } from './dto/masjid.dto';
import { RoleType, MasjidApprovalStatus, Prisma } from '@prisma/client';
import { randomBytes } from 'crypto';

@Injectable()
export class MasjidsService {
  constructor(private prisma: PrismaService) {}

  async findAll(query?: {
    city?: string;
    search?: string;
    page?: number;
    limit?: number;
    sort?: string;
    latitude?: number;
    longitude?: number;
  }) {
    const page = Number.isFinite(query?.page)
      ? Math.max(1, Math.floor(query!.page!))
      : 1;
    const limit = Number.isFinite(query?.limit)
      ? Math.min(50, Math.max(1, Math.floor(query!.limit!)))
      : 20;
    const sort = ['NAME_ASC', 'NAME_DESC', 'NEAREST'].includes(query?.sort ?? '')
      ? query!.sort!
      : 'NAME_ASC';
    const where: Prisma.MasjidWhereInput = {
      isActive: true,
      approvalStatus: MasjidApprovalStatus.APPROVED,
    };
    if (query?.city) {
      where.city = { contains: query.city, mode: 'insensitive' };
    }
    if (query?.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { nameTa: { contains: query.search, mode: 'insensitive' } },
        { city: { contains: query.search, mode: 'insensitive' } },
        { address: { contains: query.search, mode: 'insensitive' } },
        { state: { contains: query.search, mode: 'insensitive' } },
      ];
    }
    const locationFilter = sort === 'NEAREST';
    if (locationFilter) {
      const latitude = query?.latitude;
      const longitude = query?.longitude;
      if (
        latitude == null || longitude == null ||
        !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180
      ) {
        throw new BadRequestException('Valid latitude and longitude are required for nearby search');
      }
      where.latitude = { not: null };
      where.longitude = { not: null };
      const conditions: Prisma.Sql[] = [
        Prisma.sql`m.is_active = TRUE`,
        Prisma.sql`m.approval_status = 'APPROVED'`,
        Prisma.sql`m.latitude IS NOT NULL`,
        Prisma.sql`m.longitude IS NOT NULL`,
      ];
      if (query?.city?.trim()) {
        conditions.push(Prisma.sql`m.city ILIKE ${`%${query.city.trim()}%`}`);
      }
      if (query?.search?.trim()) {
        const term = `%${query.search.trim()}%`;
        conditions.push(Prisma.sql`(
          m.name ILIKE ${term} OR m.name_ta ILIKE ${term} OR
          m.city ILIKE ${term} OR m.address ILIKE ${term} OR m.state ILIKE ${term}
        )`);
      }
      const distanceExpression = Prisma.sql`(
        6371 * acos(least(1, greatest(-1,
          sin(radians(m.latitude::double precision)) * sin(radians(${latitude})) +
          cos(radians(m.latitude::double precision)) * cos(radians(${latitude})) *
          cos(radians(m.longitude::double precision) - radians(${longitude}))
        )))
      )`;
      const [total, distances] = await Promise.all([
        this.prisma.masjid.count({ where }),
        this.prisma.$queryRaw<Array<{ id: string; distanceKm: number }>>(Prisma.sql`
          SELECT m.id, ${distanceExpression} AS "distanceKm"
          FROM masjids m
          WHERE ${Prisma.join(conditions, ' AND ')}
          ORDER BY "distanceKm" ASC, m.id ASC
          LIMIT ${limit} OFFSET ${(page - 1) * limit}
        `),
      ]);
      const ids = distances.map((item) => item.id);
      const records = ids.length
        ? await this.prisma.masjid.findMany({
            where: { id: { in: ids } },
            select: {
              id: true, name: true, nameTa: true, address: true,
              latitude: true, longitude: true, city: true, state: true,
              country: true, photoUrl: true, mapUrl: true,
            },
          })
        : [];
      const byId = new Map(records.map((record) => [record.id, record]));
      const items = distances.flatMap((item) => {
        const record = byId.get(item.id);
        return record ? [{ ...record, distanceKm: Number(item.distanceKm) }] : [];
      });
      return { items, total, page, limit, hasMore: page * limit < total };
    }

    const [total, items] = await Promise.all([
      this.prisma.masjid.count({ where }),
      this.prisma.masjid.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: sort === 'NAME_DESC'
          ? [{ name: 'desc' }, { id: 'asc' }]
          : [{ name: 'asc' }, { id: 'asc' }],
        select: {
          id: true, name: true, nameTa: true, address: true,
          latitude: true, longitude: true, city: true, state: true,
          country: true, photoUrl: true, mapUrl: true,
        },
      }),
    ]);
    return { items, total, page, limit, hasMore: page * limit < total };
  }

  async listAdminDirectory(query: { search?: string; status?: string; page?: number; limit?: number }) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, Math.max(1, query.limit || 20));
    const where: Prisma.MasjidWhereInput = {};
    if (query.status === 'ACTIVE') where.isActive = true;
    if (query.status === 'INACTIVE') where.isActive = false;
    if (query.status === 'PENDING') where.approvalStatus = MasjidApprovalStatus.PENDING;
    if (query.search?.trim()) {
      const term = query.search.trim();
      where.OR = [
        { name: { contains: term, mode: 'insensitive' } },
        { nameTa: { contains: term, mode: 'insensitive' } },
        { city: { contains: term, mode: 'insensitive' } },
        { address: { contains: term, mode: 'insensitive' } },
      ];
    }
    const [total, items] = await Promise.all([
      this.prisma.masjid.count({ where }),
      this.prisma.masjid.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { _count: { select: { memberships: true, admins: true } } },
      }),
    ]);
    return { total, page, limit, items };
  }

  async setMasjidActive(masjidId: string, isActive: boolean) {
    const masjid = await this.prisma.masjid.findUnique({ where: { id: masjidId } });
    if (!masjid) throw new NotFoundException('Masjid not found');
    if (isActive && masjid.approvalStatus !== MasjidApprovalStatus.APPROVED) {
      throw new BadRequestException('Only approved masjids can be activated');
    }
    return this.prisma.masjid.update({ where: { id: masjidId }, data: { isActive } });
  }

  async findById(id: string) {
    let masjid = await this.prisma.masjid.findUnique({
      where: { id },
      include: {
        admins: {
          include: {
            user: { select: { id: true, name: true, phone: true } },
            role: true,
          },
        },
      },
    });
    if (!masjid) {
      throw new NotFoundException('Masjid not found');
    }
    // Auto-generate qrToken if missing
    if (!masjid.qrToken) {
      const generated = randomBytes(16).toString('hex');
      masjid = await this.prisma.masjid.update({
        where: { id },
        data: { qrToken: generated },
        include: {
          admins: {
            include: {
              user: { select: { id: true, name: true, phone: true } },
              role: true,
            },
          },
        },
      });
    }
    return masjid;
  }

  async findByQrToken(qrToken: string) {
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(qrToken);
    const masjid = await this.prisma.masjid.findFirst({
      where: {
        isActive: true,
        approvalStatus: MasjidApprovalStatus.APPROVED,
        ...(isUuid ? { OR: [{ qrToken }, { id: qrToken }] } : { qrToken }),
      },
    });
    if (!masjid) {
      throw new NotFoundException('Invalid or expired Masjid QR code');
    }
    return masjid;
  }

  async checkDuplicateLocation(latitude?: number, longitude?: number, name?: string, city?: string) {
    if (latitude != null && longitude != null) {
      const allMasjids = await this.prisma.masjid.findMany({
        where: {
          latitude: { not: null },
          longitude: { not: null },
        },
        select: { id: true, name: true, latitude: true, longitude: true },
      });

      for (const m of allMasjids) {
        if (m.latitude && m.longitude) {
          const latDiff = Math.abs(Number(m.latitude) - Number(latitude));
          const lngDiff = Math.abs(Number(m.longitude) - Number(longitude));
          // roughly ~100m distance threshold
          if (latDiff < 0.001 && lngDiff < 0.001) {
            throw new BadRequestException(
              `Duplicate Masjid Detected: "${m.name}" is already registered within ~100 meters of these coordinates. Duplicate masjids are not allowed.`,
            );
          }
        }
      }
    }

    if (name && city) {
      const existingSame = await this.prisma.masjid.findFirst({
        where: {
          name: { equals: name.trim(), mode: 'insensitive' },
          city: { equals: city.trim(), mode: 'insensitive' },
        },
      });
      if (existingSame) {
        throw new BadRequestException(
          `A Masjid with the name "${name}" is already registered in ${city}.`,
        );
      }
    }
  }

  async create(userId: string, dto: CreateMasjidDto) {
    // 1. Prevent duplicates
    await this.checkDuplicateLocation(dto.latitude, dto.longitude, dto.name, dto.city);

    // 2. Check if user is Super Admin
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const isSuperAdmin = user?.isSuperAdmin === true;

    if (isSuperAdmin && dto.adminPhone?.trim()) {
      const cleanPhone = dto.adminPhone.trim().replace(/\D/g, '').slice(-10);
      if (cleanPhone.length !== 10) {
        throw new BadRequestException('Enter a valid 10-digit administrator mobile number');
      }
      const normalizedPhone = `+91${cleanPhone}`;
      const existingAdmin = await this.prisma.user.findFirst({
        where: { OR: [{ phone: normalizedPhone }, { phone: cleanPhone }] },
        select: { id: true },
      });
      if (!existingAdmin && !dto.adminName?.trim()) {
        throw new BadRequestException('Enter the administrator name when adding a new mobile number');
      }
    }

    const qrToken = randomBytes(16).toString('hex'); // 32-character permanent token

    const approvalStatus = isSuperAdmin ? MasjidApprovalStatus.APPROVED : MasjidApprovalStatus.PENDING;
    const isActive = isSuperAdmin;

    const { adminName, adminPhone, ...masjidPayload } = dto;

    // Auto-extract lat/lng from mapUrl if not manually provided
    let latitude = dto.latitude;
    let longitude = dto.longitude;
    if ((latitude == null || longitude == null) && dto.mapUrl) {
      const atMatch = dto.mapUrl.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
      const qMatch = dto.mapUrl.match(/(?:q|query|ll)=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)/);
      const genMatch = dto.mapUrl.match(/(-?\d{1,2}\.\d{3,10})\s*,\s*(-?\d{1,3}\.\d{3,10})/);
      const match = atMatch || qMatch || genMatch;
      if (match) {
        latitude = parseFloat(match[1]);
        longitude = parseFloat(match[2]);
      }
    }

    const masjidData: any = {
      ...masjidPayload,
      ...(latitude != null ? { latitude } : {}),
      ...(longitude != null ? { longitude } : {}),
      qrToken,
      approvalStatus,
      isActive,
      createdBy: userId,
    };

    const masjid = await this.prisma.masjid.create({
      data: masjidData,
    });

    if (!isSuperAdmin) {
      return {
        ...masjid,
        isPendingApproval: true,
        message: 'Masjid request submitted. A Super Admin must approve it before it becomes searchable.',
      };
    }

    const adminRole = await this.prisma.role.findUniqueOrThrow({
      where: { name: RoleType.ADMIN },
    });

    // Check if an admin phone was specified (e.g. created by Super Admin)
    let assignedAdminUserId = userId;
    if (adminPhone && adminPhone.trim().length >= 10) {
      const cleanPhone = adminPhone.trim().replace(/\D/g, '').slice(-10);
      const normalizedPhone = `+91${cleanPhone}`;
      let adminUser = await this.prisma.user.findFirst({
        where: {
          OR: [{ phone: normalizedPhone }, { phone: cleanPhone }],
        },
      });

      if (!adminUser) {
        adminUser = await this.prisma.user.create({
          data: {
            phone: normalizedPhone,
            name: adminName!.trim(),
            isOnboarded: true,
            isActive: true,
          } as any,
        });
      } else {
        await this.prisma.user.update({
          where: { id: adminUser.id },
          data: {
            phone: normalizedPhone,
            isOnboarded: true,
            ...(adminName && adminName.trim().length > 0 ? { name: adminName.trim() } : {}),
          } as any,
        });
      }

      assignedAdminUserId = adminUser.id;

      // Also assign creator if creator is different
      if (userId !== assignedAdminUserId) {
        await this.prisma.masjidAdmin.upsert({
          where: {
            idx_masjid_admins_unique: {
              userId,
              masjidId: masjid.id,
              roleId: adminRole.id,
            },
          },
          update: {},
          create: {
            userId,
            masjidId: masjid.id,
            roleId: adminRole.id,
          },
        });
      }
    }

    // Link assignedAdminUserId as ADMIN
    await this.prisma.masjidAdmin.upsert({
      where: {
        idx_masjid_admins_unique: {
          userId: assignedAdminUserId,
          masjidId: masjid.id,
          roleId: adminRole.id,
        },
      },
      update: {},
      create: {
        userId: assignedAdminUserId,
        masjidId: masjid.id,
        roleId: adminRole.id,
      },
    });

    await this.prisma.membership.upsert({
      where: {
        idx_memberships_unique: {
          userId: assignedAdminUserId,
          masjidId: masjid.id,
        },
      },
      update: { isPrimary: true },
      create: {
        userId: assignedAdminUserId,
        masjidId: masjid.id,
        isPrimary: true,
      },
    });

    return {
      ...masjid,
      isPendingApproval: false,
      message: 'Masjid created and approved successfully. Creator has been granted Masjid Admin role.',
    };
  }

  async getPendingRequests() {
    return this.prisma.masjid.findMany({
      where: {
        approvalStatus: MasjidApprovalStatus.PENDING,
      },
      include: {
        creator: {
          select: {
            id: true,
            name: true,
            phone: true,
            address: true,
            createdAt: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async approveRequest(masjidId: string) {
    const masjid = await this.prisma.masjid.findUnique({
      where: { id: masjidId },
    });

    if (!masjid) {
      throw new NotFoundException('Masjid request not found');
    }
    if (masjid.approvalStatus !== MasjidApprovalStatus.PENDING) {
      throw new BadRequestException('Only pending masjid requests can be approved');
    }

    const updated = await this.prisma.masjid.update({
      where: { id: masjidId },
      data: {
        approvalStatus: MasjidApprovalStatus.APPROVED,
        isActive: true,
      } as any,
    });

    // Make applicant an ADMIN of this masjid
    const adminRole = await this.prisma.role.findUniqueOrThrow({
      where: { name: RoleType.ADMIN },
    });

    await this.prisma.masjidAdmin.upsert({
      where: {
        idx_masjid_admins_unique: {
          userId: masjid.createdBy,
          masjidId: masjid.id,
          roleId: adminRole.id,
        },
      },
      update: {},
      create: {
        userId: masjid.createdBy,
        masjidId: masjid.id,
        roleId: adminRole.id,
      },
    });

    // Auto-join as primary member
    await this.prisma.membership.upsert({
      where: {
        idx_memberships_unique: {
          userId: masjid.createdBy,
          masjidId: masjid.id,
        },
      },
      update: { isPrimary: true },
      create: {
        userId: masjid.createdBy,
        masjidId: masjid.id,
        isPrimary: true,
      },
    });

    return {
      success: true,
      message: `Masjid "${masjid.name}" approved successfully. Creator has been granted Masjid Admin role.`,
      masjid: updated,
    };
  }

  async rejectRequest(masjidId: string, reason?: string) {
    const masjid = await this.prisma.masjid.findUnique({
      where: { id: masjidId },
    });

    if (!masjid) {
      throw new NotFoundException('Masjid request not found');
    }
    if (masjid.approvalStatus !== MasjidApprovalStatus.PENDING) {
      throw new BadRequestException('Only pending masjid requests can be rejected');
    }

    const updated = await this.prisma.masjid.update({
      where: { id: masjidId },
      data: {
        approvalStatus: MasjidApprovalStatus.REJECTED,
        rejectionReason: reason || 'Registration rejected by administrator',
        isActive: false,
      } as any,
    });

    return {
      success: true,
      message: `Masjid "${masjid.name}" request has been rejected.`,
      masjid: updated,
    };
  }

  async joinMasjid(userId: string, masjidId: string, isPrimary = false) {
    const masjid = await this.prisma.masjid.findUnique({
      where: { id: masjidId },
      select: { id: true, isActive: true, approvalStatus: true },
    });
    if (!masjid || !masjid.isActive || masjid.approvalStatus !== MasjidApprovalStatus.APPROVED) {
      throw new NotFoundException('This masjid is not available to join');
    }

    if (isPrimary) {
      // Clear previous primary
      await this.prisma.membership.updateMany({
        where: { userId, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    return this.prisma.membership.upsert({
      where: {
        idx_memberships_unique: {
          userId,
          masjidId,
        },
      },
      update: {
        ...(isPrimary ? { isPrimary: true } : {}),
      },
      create: {
        userId,
        masjidId,
        isPrimary,
      },
      include: {
        masjid: true,
      },
    });
  }

  async leaveMasjid(userId: string, masjidId: string) {
    const existing = await this.prisma.membership.findUnique({
      where: {
        idx_memberships_unique: {
          userId,
          masjidId,
        },
      },
    });

    if (existing) {
      await this.prisma.membership.delete({
        where: {
          idx_memberships_unique: {
            userId,
            masjidId,
          },
        },
      });
    }

    return {
      success: true,
      message: 'Successfully left masjid',
    };
  }

  async getMyMasjids(userId: string) {
    const [memberships, adminRoles] = await Promise.all([
      this.prisma.membership.findMany({
        where: { userId },
        include: { masjid: true },
        orderBy: { joinedAt: 'desc' },
      }),
      this.prisma.masjidAdmin.findMany({
        where: { userId },
        include: { masjid: true, role: true },
      }),
    ]);

    const masjidMap = new Map<string, any>();

    for (const m of memberships) {
      if (m.masjid && m.masjid.isActive) {
        masjidMap.set(m.masjid.id, {
          ...m.masjid,
          isPrimary: m.isPrimary,
          joinedAt: m.joinedAt,
          role: 'MEMBER',
        });
      }
    }

    for (const a of adminRoles) {
      if (a.masjid && a.masjid.isActive) {
        const existing = masjidMap.get(a.masjid.id);
        masjidMap.set(a.masjid.id, {
          ...a.masjid,
          isPrimary: existing?.isPrimary ?? false,
          role: a.role?.name || 'ADMIN',
        });
      }
    }

    return Array.from(masjidMap.values());
  }

  async update(id: string, dto: any) {
    const masjid = await this.prisma.masjid.findUnique({ where: { id } });
    if (!masjid) {
      throw new NotFoundException('Masjid not found');
    }
    const { adminName, adminPhone, ...updatePayload } = dto;
    return this.prisma.masjid.update({
      where: { id },
      data: updatePayload as any,
    });
  }

  async getMembers(masjidId: string) {
    const [memberships, admins] = await Promise.all([
      this.prisma.membership.findMany({
        where: { masjidId },
        include: {
          user: {
            select: { id: true, name: true, phone: true, address: true, createdAt: true },
          },
        },
        orderBy: { joinedAt: 'desc' },
      }),
      this.prisma.masjidAdmin.findMany({
        where: { masjidId },
        include: {
          user: { select: { id: true, name: true, phone: true } },
          role: true,
        },
      }),
    ]);

    return {
      memberships: memberships.map((m) => ({
        id: m.id,
        userId: m.userId,
        name: m.user.name,
        phone: m.user.phone,
        address: m.user.address,
        isPrimary: m.isPrimary,
        joinedAt: m.joinedAt,
      })),
      admins: admins.map((a) => ({
        id: a.id,
        userId: a.userId,
        name: a.user.name,
        phone: a.user.phone,
        role: a.role.name,
      })),
    };
  }

  async addMember(masjidId: string, phone: string, name?: string) {
    let user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          name: name || 'Member',
          isActive: true,
        },
      });
    }

    return this.prisma.membership.upsert({
      where: {
        idx_memberships_unique: {
          userId: user.id,
          masjidId,
        },
      },
      update: { isPrimary: true },
      create: {
        userId: user.id,
        masjidId,
        isPrimary: true,
      },
      include: {
        user: { select: { id: true, name: true, phone: true } },
      },
    });
  }

  async assignRole(masjidId: string, dto: AssignRoleDto) {
    let targetUser = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (!targetUser) {
      targetUser = await this.prisma.user.create({
        data: {
          phone: dto.phone,
          name: dto.name,
          isActive: true,
        },
      });
    }

    const role = await this.prisma.role.findUnique({
      where: { name: dto.role as RoleType },
    });

    if (!role) {
      throw new BadRequestException(`Role ${dto.role} is invalid`);
    }

    return this.prisma.masjidAdmin.upsert({
      where: {
        idx_masjid_admins_unique: {
          userId: targetUser.id,
          masjidId,
          roleId: role.id,
        },
      },
      update: {},
      create: {
        userId: targetUser.id,
        masjidId,
        roleId: role.id,
      },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        role: true,
      },
    });
  }

  async deleteMasjid(masjidId: string) {
    const masjid = await this.prisma.masjid.findUnique({ where: { id: masjidId } });
    if (!masjid) {
      throw new NotFoundException('Masjid not found');
    }

    return this.prisma.$transaction(async (tx) => {
      // 1. Delete prayer times & special schedules
      await tx.prayerTime.deleteMany({ where: { masjidId } });
      await tx.specialSchedule.deleteMany({ where: { masjidId } });

      // 2. Delete announcements
      await tx.announcement.deleteMany({ where: { masjidId } });

      // 3. Delete memberships, notification prefs & masjid admins
      await tx.membership.deleteMany({ where: { masjidId } });
      await tx.notificationPref.deleteMany({ where: { masjidId } });
      await tx.masjidAdmin.deleteMany({ where: { masjidId } });

      // 4. Delete sandha plans, plan members & payments
      const plans = await tx.sandhaPlan.findMany({ where: { masjidId }, select: { id: true } });
      const planIds = plans.map((p) => p.id);
      if (planIds.length > 0) {
        await tx.sandhaPayment.deleteMany({ where: { planId: { in: planIds } } });
        await tx.sandhaPlanMember.deleteMany({ where: { planId: { in: planIds } } });
        await tx.sandhaPlan.deleteMany({ where: { masjidId } });
      }

      // 5. Delete the masjid
      return tx.masjid.delete({ where: { id: masjidId } });
    });
  }
}
