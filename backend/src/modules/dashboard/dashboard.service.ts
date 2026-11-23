import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private prisma: PrismaService) {}

  async getSuperAdminOverview() {
    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);
    const activeSince = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const [
      totalMasjids,
      totalUsers,
      totalMemberships,
      totalSandhaPlans,
      paymentsSummary,
      recentMasjids,
      pendingRequestsCount,
      pendingRequests,
      activeDeviceUsers,
      activePlans,
      currentMonthPayments,
    ] = await Promise.all([
      this.prisma.masjid.count({ where: { isActive: true } }),
      this.prisma.user.count(),
      this.prisma.membership.count(),
      this.prisma.sandhaPlan.count({ where: { isActive: true } }),
      this.prisma.sandhaPayment.aggregate({
        where: { status: { in: ['PAID', 'PARTIAL'] } },
        _sum: { amount: true },
        _count: { id: true },
      }),
      this.prisma.masjid.findMany({
        take: 5,
        where: { isActive: true },
        orderBy: { createdAt: 'desc' },
        include: {
          _count: { select: { memberships: true, admins: true } },
        },
      }),
      this.prisma.masjid.count({ where: { approvalStatus: 'PENDING' } }),
      this.prisma.masjid.findMany({
        where: { approvalStatus: 'PENDING' },
        include: {
          creator: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.device.findMany({
        where: {
          isActive: true,
          lastActiveAt: { gte: activeSince },
          user: { isActive: true },
        },
        select: { userId: true },
        distinct: ['userId'],
      }),
      this.prisma.sandhaPlan.findMany({
        where: { isActive: true },
        select: { amount: true, frequency: true, _count: { select: { members: true } } },
      }),
      this.prisma.sandhaPayment.aggregate({
        where: { paidAt: { gte: monthStart }, status: { in: ['PAID', 'PARTIAL'] } },
        _sum: { amount: true },
      }),
    ]);

    const monthlyDivisors: Record<string, number> = {
      MONTHLY: 1,
      QUARTERLY: 3,
      HALF_YEARLY: 6,
      YEARLY: 12,
    };
    const monthlySandhaExpected = activePlans.reduce((total, plan) => {
      const divisor = monthlyDivisors[plan.frequency] || 1;
      return total + (Number(plan.amount) * plan._count.members) / divisor;
    }, 0);

    return {
      metrics: {
        totalMasjids,
        totalUsers,
        totalFollowers: totalMemberships,
        totalSandhaPlans,
        totalSandhaCollected: paymentsSummary._sum.amount || 0,
        currentMonthSandhaCollected: currentMonthPayments._sum.amount || 0,
        monthlySandhaExpected,
        activeUsersLast30Days: activeDeviceUsers.length,
        totalTransactions: paymentsSummary._count.id,
        pendingRequestsCount,
      },
      recentMasjids,
      pendingRequests,
    };
  }

  async getMasjidAdminOverview(masjidId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);

    const [
      masjid,
      memberCount,
      todayPrayerTimes,
      activeAnnouncements,
      sandhaPlans,
      recentPayments,
      paymentsSummary,
    ] = await Promise.all([
      this.prisma.masjid.findUnique({ where: { id: masjidId } }),
      this.prisma.membership.count({ where: { masjidId } }),
      this.prisma.prayerTime.findUnique({
        where: {
          idx_prayer_times_unique: {
            masjidId,
            date: today,
          },
        },
      }),
      this.prisma.announcement.count({
        where: {
          masjidId,
          publishedAt: { lte: new Date() },
          OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
        },
      }),
      this.prisma.sandhaPlan.findMany({
        where: { masjidId, isActive: true },
        include: {
          _count: { select: { members: true, payments: true } },
        },
      }),
      this.prisma.sandhaPayment.findMany({
        where: { plan: { masjidId } },
        take: 5,
        orderBy: { paidAt: 'desc' },
        include: {
          planMember: { select: { name: true, phone: true } },
        },
      }),
      this.prisma.sandhaPayment.aggregate({
        where: { plan: { masjidId }, paidAt: { gte: monthStart }, status: { in: ['PAID', 'PARTIAL'] } },
        _sum: { amount: true },
      }),
    ]);

    const monthlyDivisors: Record<string, number> = { MONTHLY: 1, QUARTERLY: 3, HALF_YEARLY: 6, YEARLY: 12 };
    const monthlySandhaExpected = sandhaPlans.reduce((total, plan) => {
      return total + (Number(plan.amount) * plan._count.members) / (monthlyDivisors[plan.frequency] || 1);
    }, 0);

    return {
      masjid,
      metrics: {
        memberCount,
        hasConfiguredTodayTimes: !!todayPrayerTimes,
        activeAnnouncementsCount: activeAnnouncements,
        activePlansCount: sandhaPlans.length,
        monthlySandhaExpected,
        currentMonthSandhaCollected: paymentsSummary._sum.amount || 0,
      },
      todayPrayerTimes,
      sandhaPlans,
      recentPayments,
    };
  }
}
