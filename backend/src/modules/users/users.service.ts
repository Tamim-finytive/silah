import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { UpdateProfileDto, CreateUserDto } from './dto/users.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        memberships: {
          include: { masjid: true },
        },
        masjidAdmins: {
          include: { masjid: true, role: true },
        },
      },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
    });
  }

  async createUser(dto: CreateUserDto) {
    const existing = await this.prisma.user.findUnique({ where: { phone: dto.phone } });
    if (existing) {
      throw new BadRequestException('User with this mobile number already exists');
    }

    const userData: any = {
      phone: dto.phone,
      name: dto.name,
      address: dto.address,
      isSuperAdmin: dto.isSuperAdmin || false,
      isOnboarded: true,
      isActive: true,
    };

    return this.prisma.user.create({
      data: userData,
    });
  }

  async listAllUsers(query?: { search?: string; page?: number; limit?: number }) {
    const page = query?.page || 1;
    const limit = Math.min(100, Math.max(1, query?.limit || 20));
    const skip = (page - 1) * limit;

    const where: any = {};
    if (query?.search) {
      where.OR = [
        { name: { contains: query.search, mode: 'insensitive' } },
        { phone: { contains: query.search } },
      ];
    }

    const [total, items] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return { total, page, limit, items };
  }

  async setUserActive(userId: string, isActive: boolean, adminUserId: string) {
    if (userId === adminUserId && !isActive) {
      throw new BadRequestException('Cannot deactivate your own account');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (user.isSuperAdmin && !isActive) {
      const activeSuperAdmins = await this.prisma.user.count({ where: { isSuperAdmin: true, isActive: true } });
      if (activeSuperAdmins <= 1) throw new BadRequestException('At least one active Super Admin must remain');
    }
    return this.prisma.user.update({ where: { id: userId }, data: { isActive } });
  }

  async deleteUser(userId: string, adminUserId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (userId === adminUserId) {
      throw new BadRequestException('Cannot delete your own Super Admin account');
    }

    return this.prisma.$transaction(async (tx) => {
      // Reassign or cleanup entities authored by this user so foreign keys don't violate
      await tx.masjid.updateMany({ where: { createdBy: userId }, data: { createdBy: adminUserId } });
      await tx.announcement.updateMany({ where: { createdBy: userId }, data: { createdBy: adminUserId } });
      await tx.specialSchedule.updateMany({ where: { createdBy: userId }, data: { createdBy: adminUserId } });
      await tx.sandhaPlan.updateMany({ where: { createdBy: userId }, data: { createdBy: adminUserId } });
      await tx.sandhaPayment.updateMany({ where: { recordedBy: userId }, data: { recordedBy: adminUserId } });
      await tx.sandhaPayment.deleteMany({ where: { userId } });
      await tx.sandhaPlanMember.updateMany({ where: { userId }, data: { userId: null } });
      await tx.prayerTime.updateMany({ where: { updatedBy: userId }, data: { updatedBy: adminUserId } });

      // Delete user relations
      await tx.masjidAdmin.deleteMany({ where: { userId } });
      await tx.membership.deleteMany({ where: { userId } });
      await tx.device.deleteMany({ where: { userId } });
      await tx.notificationPref.deleteMany({ where: { userId } });

      return tx.user.delete({ where: { id: userId } });
    });
  }
}
