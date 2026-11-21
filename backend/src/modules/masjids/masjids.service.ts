import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { CreateMasjidDto, AssignRoleDto } from './dto/masjid.dto';
import { RoleType, MasjidApprovalStatus } from '@prisma/client';
import { randomBytes } from 'crypto';

@Injectable()
export class MasjidsService {
  constructor(private prisma: PrismaService) {}

  async findAll(query?: { city?: string; search?: string }) {
    const where: any = {
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
      ];
    }
    return this.prisma.masjid.findMany({
      where,
      orderBy: { name: 'asc' },
    });
  }

  async findById(id: string) {
    const masjid = await this.prisma.masjid.findUnique({
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
    return masjid;
  }

  async findByQrToken(qrToken: string) {
    const masjid = await this.prisma.masjid.findUnique({
      where: { qrToken },
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

    const qrToken = randomBytes(16).toString('hex'); // 32-character permanent token

    // Regular users create pending requests; Super Admin can create directly active
    const approvalStatus = isSuperAdmin ? MasjidApprovalStatus.APPROVED : MasjidApprovalStatus.PENDING;
    const isActive = isSuperAdmin;

    const masjid = await this.prisma.masjid.create({
      data: {
        ...dto,
        qrToken,
        approvalStatus,
        isActive,
        createdBy: userId,
      },
    });

    if (isSuperAdmin) {
      // Make creator an ADMIN directly
      const adminRole = await this.prisma.role.findUniqueOrThrow({
        where: { name: RoleType.ADMIN },
      });

      await this.prisma.masjidAdmin.create({
        data: {
          userId,
          masjidId: masjid.id,
          roleId: adminRole.id,
        },
      });

      await this.prisma.membership.upsert({
        where: {
          idx_memberships_unique: {
            userId,
            masjidId: masjid.id,
          },
        },
        update: { isPrimary: true },
        create: {
          userId,
          masjidId: masjid.id,
          isPrimary: true,
        },
      });
    }

    return {
      ...masjid,
      isPendingApproval: !isSuperAdmin,
      message: isSuperAdmin
        ? 'Masjid created and approved.'
        : 'Masjid registration request submitted! It will be reviewed and approved by the Super Admin.',
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
            age: true,
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

    const updated = await this.prisma.masjid.update({
      where: { id: masjidId },
      data: {
        approvalStatus: MasjidApprovalStatus.APPROVED,
        isActive: true,
      },
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

    const updated = await this.prisma.masjid.update({
      where: { id: masjidId },
      data: {
        approvalStatus: MasjidApprovalStatus.REJECTED,
        rejectionReason: reason || 'Registration rejected by administrator',
        isActive: false,
      },
    });

    return {
      success: true,
      message: `Masjid "${masjid.name}" request has been rejected.`,
      masjid: updated,
    };
  }

  async joinMasjid(userId: string, masjidId: string, isPrimary = false) {
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
}
