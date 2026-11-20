import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';
import { CreateMasjidDto, AssignRoleDto } from './dto/masjid.dto';
import { RoleType } from '@prisma/client';
import { randomBytes } from 'crypto';

@Injectable()
export class MasjidsService {
  constructor(private prisma: PrismaService) {}

  async findAll(query?: { city?: string; search?: string }) {
    const where: any = { isActive: true };
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

  async create(userId: string, dto: CreateMasjidDto) {
    const qrToken = randomBytes(16).toString('hex'); // 32-character permanent token

    const masjid = await this.prisma.masjid.create({
      data: {
        ...dto,
        qrToken,
        createdBy: userId,
      },
    });

    // Make the creator an ADMIN of this masjid
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

    // Also auto-join as primary member
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

    return masjid;
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
