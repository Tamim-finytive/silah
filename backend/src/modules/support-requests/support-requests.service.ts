import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { SupportRequestStatus } from "@prisma/client";
import { PrismaService } from "../../common/prisma/prisma.service";
import { FirebaseService } from "../../common/firebase/firebase.service";
import { CreateSupportRequestDto } from "./dto/create-support-request.dto";

@Injectable()
export class SupportRequestsService {
  private readonly logger = new Logger(SupportRequestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly firebase: FirebaseService,
  ) {}

  async create(dto: CreateSupportRequestDto) {
    if (
      !dto.name.trim() ||
      !dto.phone.trim() ||
      !dto.subject.trim() ||
      !dto.message.trim()
    ) {
      throw new BadRequestException(
        "Name, phone, heading, and message are required",
      );
    }
    const phone = this.normalizePhone(dto.phone);
    const recentCount = await this.prisma.supportRequest.count({
      where: {
        phone,
        createdAt: { gte: new Date(Date.now() - 15 * 60 * 1000) },
      },
    });
    if (recentCount >= 3) {
      throw new HttpException(
        "Too many messages from this number. Please try again later.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const request = await this.prisma.supportRequest.create({
      data: {
        name: dto.name.trim(),
        phone,
        subject: dto.subject.trim(),
        message: dto.message.trim(),
      },
    });

    // The database record is authoritative. Push failure must not discard a valid request.
    try {
      const devices = await this.prisma.device.findMany({
        where: {
          isActive: true,
          user: { isActive: true, isSuperAdmin: true },
        },
        select: { id: true, fcmToken: true },
      });
      const delivery = await this.firebase.sendPushNotification(
        devices.map((device) => device.fcmToken),
        "New Contact Us message",
        `${request.subject} · ${request.name} sent a message`,
        {
          type: "SUPPORT_REQUEST",
          requestId: request.id,
          title: "New Contact Us message",
          body: request.subject,
        },
      );
      if (delivery.invalidTokens.length) {
        await this.prisma.device.updateMany({
          where: { fcmToken: { in: delivery.invalidTokens } },
          data: { isActive: false },
        });
      }
      this.logger.log(
        `Contact request ${request.id}: push sent to ${delivery.successCount}/${devices.length} Super Admin devices`,
      );
    } catch (error) {
      this.logger.error(`Contact request ${request.id} push failed: ${error}`);
    }

    return {
      id: request.id,
      status: request.status,
      createdAt: request.createdAt,
    };
  }

  async list(query: { status?: string; page?: number; limit?: number }) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(50, Math.max(1, query.limit || 20));
    const status = query.status?.toUpperCase();
    const validStatuses = Object.values(SupportRequestStatus);
    if (
      status &&
      status !== "ALL" &&
      !validStatuses.includes(status as SupportRequestStatus)
    ) {
      throw new BadRequestException("Invalid contact request status");
    }
    const where =
      status && status !== "ALL"
        ? { status: status as SupportRequestStatus }
        : {};
    const [total, items] = await Promise.all([
      this.prisma.supportRequest.count({ where }),
      this.prisma.supportRequest.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return { items, total, page, limit, hasMore: page * limit < total };
  }

  async updateStatus(
    id: string,
    reviewerId: string,
    status: SupportRequestStatus,
  ) {
    const existing = await this.prisma.supportRequest.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException("Contact request not found");
    return this.prisma.supportRequest.update({
      where: { id },
      data: {
        status,
        reviewedBy: reviewerId,
      },
    });
  }

  private normalizePhone(input: string) {
    const raw = input.trim().replace(/\D/g, "");
    return raw.length === 10 ? `+91${raw}` : `+${raw}`;
  }
}
