import { Controller, Get, Post, Body, Param, UseGuards, Put, Delete, Query, ParseIntPipe, DefaultValuePipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SandhaService } from './sandha.service';
import { CreateSandhaPlanDto, EnrollMemberDto, RecordPaymentDto, ReviewPaymentDto, SubmitPaymentProofDto } from './dto/sandha.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { MasjidRoleGuard } from '../../common/guards/masjid-role.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { MasjidRoles } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Sandha')
@Controller('masjids/:masjidId/sandha')
export class SandhaController {
  constructor(private readonly sandhaService: SandhaService) {}

  @Get('plans')
  @ApiOperation({ summary: 'List sandha plans for a masjid' })
  async getPlans(@Param('masjidId') masjidId: string) {
    return this.sandhaService.getPlans(masjidId);
  }

  @Post('plans')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a new sandha plan (Admin or Finance)' })
  async createPlan(
    @Param('masjidId') masjidId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateSandhaPlanDto,
  ) {
    return this.sandhaService.createPlan(masjidId, userId, dto);
  }

  @Put('plans/:planId')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  async updatePlan(@Param('masjidId') masjidId: string, @Param('planId') planId: string, @Body() dto: CreateSandhaPlanDto) {
    return this.sandhaService.updatePlan(masjidId, planId, dto);
  }

  @Get('members')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List enrolled sandha members with current month status' })
  async getMembers(
    @Param('masjidId') masjidId: string,
    @Query('planId') planId?: string,
    @Query('month') month?: string,
  ) {
    return this.sandhaService.getMembers(masjidId, planId, month);
  }

  @Delete('members/:memberId')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Remove a member from sandha plan' })
  async removeMember(
    @Param('masjidId') masjidId: string,
    @Param('memberId') memberId: string,
  ) {
    return this.sandhaService.removeMember(masjidId, memberId);
  }

  @Post('plans/:planId/members')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Enroll a member into sandha plan with auto-linking by phone' })
  async enrollMember(
    @Param('masjidId') masjidId: string,
    @Param('planId') planId: string,
    @Body() dto: EnrollMemberDto,
  ) {
    return this.sandhaService.enrollMember(planId, dto);
  }

  @Post('payments')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Record a sandha payment (Cash, UPI, etc.)' })
  async recordPayment(
    @Param('masjidId') masjidId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: RecordPaymentDto,
  ) {
    return this.sandhaService.recordPayment(masjidId, userId, dto);
  }

  @Post('payments/proof')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  async submitPaymentProof(@Param('masjidId') masjidId: string, @CurrentUser('id') userId: string, @Body() dto: SubmitPaymentProofDto) {
    return this.sandhaService.submitPaymentProof(masjidId, userId, dto);
  }

  @Get('admin/payments')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  async getAdminPayments(
    @Param('masjidId') masjidId: string,
    @Query('month') month: string,
    @Query('status') status = 'ALL',
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit: number,
  ) {
    return this.sandhaService.getAdminMonthHistory(masjidId, month, status, page, limit);
  }

  @Put('payments/:paymentId/review')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.FINANCE)
  @ApiBearerAuth()
  async reviewPayment(@Param('masjidId') masjidId: string, @Param('paymentId') paymentId: string, @CurrentUser('id') userId: string, @Body() dto: ReviewPaymentDto) {
    return this.sandhaService.reviewPayment(masjidId, paymentId, userId, dto.decision, dto.notes);
  }

  @Get('my-status')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current logged-in user Sandha enrollment and payment history' })
  async getMyStatus(@Param('masjidId') masjidId: string, @CurrentUser('id') userId: string) {
    return this.sandhaService.getUserSandhaStatus(userId, masjidId);
  }
}
