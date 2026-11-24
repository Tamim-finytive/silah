import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaymentStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma/prisma.service';
import { UploadsService } from '../uploads/uploads.service';
import {
  CreateSandhaPlanDto,
  EnrollMemberDto,
  RecordPaymentDto,
  SubmitPaymentProofDto,
} from './dto/sandha.dto';

@Injectable()
export class SandhaService {
  constructor(
    private prisma: PrismaService,
    private uploads: UploadsService,
  ) {}

  async getPlans(masjidId: string) {
    return this.prisma.sandhaPlan.findMany({
      where: { masjidId, isActive: true },
      include: { _count: { select: { members: true, payments: true } } },
      orderBy: { createdAt: 'asc' },
    });
  }

  async createPlan(masjidId: string, userId: string, dto: CreateSandhaPlanDto) {
    return this.prisma.sandhaPlan.create({
      data: { ...dto, masjidId, createdBy: userId },
    });
  }

  async updatePlan(
    masjidId: string,
    planId: string,
    dto: CreateSandhaPlanDto,
  ) {
    const plan = await this.prisma.sandhaPlan.findFirst({
      where: { id: planId, masjidId },
      select: { id: true },
    });
    if (!plan) throw new NotFoundException('Sandha plan not found');
    return this.prisma.sandhaPlan.update({ where: { id: planId }, data: dto });
  }

  async enrollMember(planId: string, dto: EnrollMemberDto) {
    const existingUser = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    return this.prisma.sandhaPlanMember.upsert({
      where: { idx_sandha_plan_members_unique: { planId, phone: dto.phone } },
      update: {
        name: dto.name,
        ...(existingUser
          ? { userId: existingUser.id, autoLinked: true, linkedAt: new Date() }
          : {}),
      },
      create: {
        planId,
        phone: dto.phone,
        name: dto.name,
        userId: existingUser?.id || null,
        autoLinked: !!existingUser,
        linkedAt: existingUser ? new Date() : null,
      },
      include: { user: { select: { id: true, name: true, phone: true } } },
    });
  }

  async recordPayment(masjidId: string, userId: string, dto: RecordPaymentDto) {
    const member = await this.prisma.sandhaPlanMember.findFirst({
      where: { id: dto.planMemberId, plan: { masjidId } },
      include: { plan: true },
    });
    if (!member) throw new NotFoundException('Plan member not found');
    this.assertValidPeriod(dto.periodStart, dto.periodEnd);
    if (dto.amount <= 0) throw new BadRequestException('Payment amount must be greater than zero.');
    return this.prisma.sandhaPayment.create({
      data: {
        planId: member.planId,
        planMemberId: member.id,
        userId: member.userId,
        amount: dto.amount,
        method: dto.method || 'CASH',
        receiptNumber: dto.receiptNumber,
        periodStart: new Date(`${dto.periodStart}T00:00:00.000Z`),
        periodEnd: new Date(`${dto.periodEnd}T00:00:00.000Z`),
        notes: dto.notes,
        recordedBy: userId,
        paidAt: new Date(),
        status: PaymentStatus.PAID,
      },
    });
  }

  async submitPaymentProof(
    masjidId: string,
    userId: string,
    dto: SubmitPaymentProofDto,
  ) {
    const member = await this.prisma.sandhaPlanMember.findFirst({
      where: { id: dto.planMemberId, userId, plan: { masjidId, isActive: true } },
      include: { plan: true },
    });
    if (!member) throw new ForbiddenException('This Sandha plan is not linked to your account.');
    const expectedProofPath = new RegExp(
      `^sandha-proofs/${this.escapeRegExp(masjidId)}/${this.escapeRegExp(userId)}/[0-9a-f-]{36}\\.(jpg|png|webp)$`,
      'i',
    );
    if (!expectedProofPath.test(dto.proofPath)) {
      throw new ForbiddenException('This receipt upload does not belong to your account.');
    }
    this.assertValidPeriod(dto.periodStart, dto.periodEnd);
    if (dto.amount <= 0) throw new BadRequestException('Payment amount must be greater than zero.');

    const periodStart = new Date(`${dto.periodStart}T00:00:00.000Z`);
    const periodEnd = new Date(`${dto.periodEnd}T00:00:00.000Z`);
    const [pending, paid] = await Promise.all([
      this.prisma.sandhaPayment.findFirst({
        where: {
          planMemberId: member.id,
          periodStart,
          status: PaymentStatus.PENDING,
        },
        select: { id: true },
      }),
      this.prisma.sandhaPayment.aggregate({
        where: {
          planMemberId: member.id,
          periodStart,
          status: { in: [PaymentStatus.PAID, PaymentStatus.PARTIAL] },
        },
        _sum: { amount: true },
      }),
    ]);
    if (pending) {
      throw new ConflictException('A payment receipt for this month is already waiting for review.');
    }
    const balance = Number(member.plan.amount) - Number(paid._sum.amount ?? 0);
    if (dto.amount > balance + 0.009) {
      throw new BadRequestException(`Amount exceeds the remaining Sandha balance of ₹${Math.max(balance, 0).toFixed(2)}.`);
    }

    return this.prisma.sandhaPayment.create({
      data: {
        planId: member.planId,
        planMemberId: member.id,
        userId,
        amount: dto.amount,
        method: 'UPI',
        status: PaymentStatus.PENDING,
        receiptNumber: dto.receiptNumber,
        proofPath: dto.proofPath,
        periodStart,
        periodEnd,
        recordedBy: userId,
        paidAt: new Date(),
      },
    });
  }

  async reviewPayment(
    masjidId: string,
    paymentId: string,
    reviewerId: string,
    decision: 'APPROVE' | 'REJECT',
    notes?: string,
  ) {
    const payment = await this.prisma.sandhaPayment.findFirst({
      where: { id: paymentId, plan: { masjidId } },
      select: { id: true, status: true, notes: true },
    });
    if (!payment) throw new NotFoundException('Sandha payment not found');
    if (payment.status !== PaymentStatus.PENDING) {
      throw new ConflictException('Only a pending receipt can be reviewed.');
    }
    return this.prisma.sandhaPayment.update({
      where: { id: paymentId },
      data: {
        status: decision === 'APPROVE' ? PaymentStatus.PAID : PaymentStatus.REJECTED,
        verifiedAt: new Date(),
        verifiedBy: reviewerId,
        notes: notes?.trim() || payment.notes,
      },
    });
  }

  async getAdminMonthHistory(
    masjidId: string,
    month: string,
    status = 'ALL',
    page = 1,
    limit = 20,
  ) {
    const { start, next, end } = this.monthWindow(month);
    const currentPage = Math.max(1, Math.floor(page || 1));
    const pageSize = Math.min(50, Math.max(1, Math.floor(limit || 20)));
    const paymentStatuses = ['PAID', 'PARTIAL', 'PENDING', 'REJECTED', 'WAIVED'];
    if (status !== 'ALL' && !paymentStatuses.includes(status)) {
      throw new BadRequestException('Invalid Sandha payment status.');
    }
    const where = {
      plan: { masjidId },
      periodStart: { gte: start, lt: next },
      ...(status === 'ALL' ? {} : { status: status as PaymentStatus }),
    };
    const [total, payments, plans, collected, pendingProofs] = await Promise.all([
      this.prisma.sandhaPayment.count({ where }),
      this.prisma.sandhaPayment.findMany({
        where,
        orderBy: [{ paidAt: 'desc' }, { id: 'desc' }],
        skip: (currentPage - 1) * pageSize,
        take: pageSize,
        include: {
          plan: { select: { id: true, name: true, amount: true, upiId: true, payeeName: true } },
          planMember: {
            select: {
              id: true,
              name: true,
              phone: true,
              user: { select: { id: true, name: true, phone: true } },
            },
          },
          verifier: { select: { id: true, name: true } },
        },
      }),
      this.prisma.sandhaPlan.findMany({
        where: { masjidId, isActive: true },
        select: { amount: true, _count: { select: { members: true } } },
      }),
      this.prisma.sandhaPayment.aggregate({
        where: {
          plan: { masjidId },
          periodStart: { gte: start, lt: next },
          status: { in: [PaymentStatus.PAID, PaymentStatus.PARTIAL] },
        },
        _sum: { amount: true },
      }),
      this.prisma.sandhaPayment.aggregate({
        where: {
          plan: { masjidId },
          periodStart: { gte: start, lt: next },
          status: PaymentStatus.PENDING,
        },
        _sum: { amount: true },
        _count: { id: true },
      }),
    ]);
    const expected = plans.reduce(
      (sum, plan) => sum + Number(plan.amount) * plan._count.members,
      0,
    );
    const items = await Promise.all(payments.map(async (payment) => ({
      ...payment,
      proofUrl: payment.proofPath
        ? await this.uploads.createSandhaProofSignedUrl(payment.proofPath)
        : null,
      proofPath: undefined,
    })));
    return {
      items,
      page: currentPage,
      limit: pageSize,
      total,
      hasMore: currentPage * pageSize < total,
      summary: {
        month,
        expected,
        collected: Number(collected._sum.amount ?? 0),
        pendingBalance: Math.max(expected - Number(collected._sum.amount ?? 0), 0),
        pendingProofAmount: Number(pendingProofs._sum.amount ?? 0),
        pendingProofCount: pendingProofs._count.id,
      },
    };
  }

  async getUserSandhaStatus(userId: string, masjidId: string) {
    const enrollments = await this.prisma.sandhaPlanMember.findMany({
      where: { userId, plan: { masjidId } },
      include: {
        plan: { include: { masjid: { select: { id: true, name: true, nameTa: true } } } },
        payments: { orderBy: [{ paidAt: 'desc' }, { id: 'desc' }] },
      },
    });
    return Promise.all(enrollments.map(async (enrollment) => ({
      ...enrollment,
      payments: await Promise.all(enrollment.payments.map(async (payment) => ({
        ...payment,
        proofUrl: payment.proofPath
          ? await this.uploads.createSandhaProofSignedUrl(payment.proofPath)
          : null,
        proofPath: undefined,
      }))),
    })));
  }

  private assertValidPeriod(startText: string, endText: string) {
    if (!/^\d{4}-\d{2}-01$/.test(startText)) {
      throw new BadRequestException('Sandha period must start on the first day of the month.');
    }
    const start = new Date(`${startText}T00:00:00.000Z`);
    const nextMonth = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
    const expectedEnd = new Date(nextMonth.getTime() - 86400000).toISOString().slice(0, 10);
    if (Number.isNaN(start.getTime()) || endText !== expectedEnd) {
      throw new BadRequestException('Sandha period must cover a complete calendar month.');
    }
  }

  private monthWindow(month: string) {
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(month)) {
      throw new BadRequestException('Month must use YYYY-MM format.');
    }
    const [year, monthNumber] = month.split('-').map(Number);
    const start = new Date(Date.UTC(year, monthNumber - 1, 1));
    const next = new Date(Date.UTC(year, monthNumber, 1));
    const end = new Date(next.getTime() - 86400000);
    return { start, next, end };
  }

  private escapeRegExp(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }
}
