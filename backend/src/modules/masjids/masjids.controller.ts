import { Controller, Get, Post, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { MasjidsService } from './masjids.service';
import { CreateMasjidDto, AssignRoleDto } from './dto/masjid.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { MasjidRoleGuard } from '../../common/guards/masjid-role.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { MasjidRoles } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Masjids')
@Controller('masjids')
export class MasjidsController {
  constructor(private readonly masjidsService: MasjidsService) {}

  @Get()
  @ApiOperation({ summary: 'Search and list masjids (public)' })
  @ApiQuery({ name: 'city', required: false })
  @ApiQuery({ name: 'search', required: false })
  async listMasjids(@Query('city') city?: string, @Query('search') search?: string) {
    return this.masjidsService.findAll({ city, search });
  }

  @Get('requests/pending')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin: List pending masjid creation requests' })
  async getPendingRequests() {
    return this.masjidsService.getPendingRequests();
  }

  @Post('requests/:id/approve')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin: Approve a pending masjid request' })
  async approveRequest(@Param('id') id: string) {
    return this.masjidsService.approveRequest(id);
  }

  @Post('requests/:id/reject')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin: Reject a pending masjid request' })
  async rejectRequest(@Param('id') id: string, @Body('reason') reason?: string) {
    return this.masjidsService.rejectRequest(id, reason);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get masjid details by ID' })
  async getMasjid(@Param('id') id: string) {
    return this.masjidsService.findById(id);
  }

  @Get('qr/:qrToken')
  @ApiOperation({ summary: 'Lookup masjid by QR token' })
  async getByQrToken(@Param('qrToken') qrToken: string) {
    return this.masjidsService.findByQrToken(qrToken);
  }

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Register a new masjid (Self-service or Super Admin)' })
  async createMasjid(@CurrentUser('id') userId: string, @Body() dto: CreateMasjidDto) {
    return this.masjidsService.create(userId, dto);
  }

  @Post(':id/join')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Join a masjid (make it favorite/member)' })
  async joinMasjid(
    @CurrentUser('id') userId: string,
    @Param('id') masjidId: string,
    @Body('isPrimary') isPrimary?: boolean,
  ) {
    return this.masjidsService.joinMasjid(userId, masjidId, isPrimary);
  }

  @Post(':masjidId/roles')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Assign custom role (Finance/Announcement/Admin) to a member' })
  async assignRole(@Param('masjidId') masjidId: string, @Body() dto: AssignRoleDto) {
    return this.masjidsService.assignRole(masjidId, dto);
  }
}
