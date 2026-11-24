import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { AnnouncementsService } from './announcements.service';
import { CreateAnnouncementDto, BroadcastAnnouncementDto, UpdateAnnouncementDto, AnnouncementReadStateDto } from './dto/announcement.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { MasjidRoleGuard } from '../../common/guards/masjid-role.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { MasjidRoles, Roles } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Announcements')
@Controller('announcements')
export class BroadcastAnnouncementsController {
  constructor(private readonly announcementsService: AnnouncementsService) {}

  @Get('my')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List visible masjid and broadcast notices for the signed-in user' })
  @ApiQuery({ name: 'status', required: false, enum: ['ALL', 'READ', 'UNREAD'] })
  @ApiQuery({ name: 'from', required: false })
  @ApiQuery({ name: 'to', required: false })
  @ApiQuery({ name: 'cursor', required: false, description: 'Notice ID from the previous page' })
  @ApiQuery({ name: 'limit', required: false, description: 'Page size (1-50; defaults to 20)' })
  async getMyAnnouncements(
    @CurrentUser('id') userId: string,
    @Query('status') status?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.announcementsService.findForUser(userId, {
      status,
      from,
      to,
      cursor,
      limit: limit === undefined ? undefined : Number(limit),
    });
  }

  @Put(':id/read-state')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Mark a notice read or unread for the current user' })
  async setReadState(
    @CurrentUser('id') userId: string,
    @Param('id') id: string,
    @Body() dto: AnnouncementReadStateDto,
  ) {
    return this.announcementsService.setReadState(userId, id, dto.isRead);
  }

  @Delete(':id/hide')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Hide a notice from only the current user' })
  async hideForUser(@CurrentUser('id') userId: string, @Param('id') id: string) {
    return this.announcementsService.hideForUser(userId, id);
  }

  @Get('broadcasts/admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin list broadcasts with read counts' })
  async getAdminBroadcasts() {
    return this.announcementsService.findBroadcastsWithReadCounts();
  }

  @Get('broadcasts')
  @ApiOperation({ summary: 'List all system-wide broadcast announcements' })
  async getBroadcasts() {
    return this.announcementsService.findBroadcasts();
  }

  @Post('broadcasts')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin: Send system-wide broadcast announcement' })
  async createBroadcast(
    @CurrentUser('id') userId: string,
    @Body() dto: BroadcastAnnouncementDto,
  ) {
    return this.announcementsService.createBroadcast(userId, dto);
  }

  @Put('broadcasts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin edit a broadcast announcement' })
  async updateBroadcast(
    @Param('id') id: string,
    @Body() dto: UpdateAnnouncementDto,
  ) {
    return this.announcementsService.updateBroadcast(id, dto);
  }

  @Delete('broadcasts/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Super Admin: Delete broadcast announcement' })
  async deleteBroadcast(@Param('id') id: string) {
    return this.announcementsService.deleteBroadcast(id);
  }
}

@ApiTags('Announcements')
@Controller('masjids/:masjidId/announcements')
export class MasjidAnnouncementsController {
  constructor(private readonly announcementsService: AnnouncementsService) {}

  @Get('admin')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.ANNOUNCEMENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List masjid notices with per-notice read counts' })
  async getAdminAnnouncements(@Param('masjidId') masjidId: string) {
    return this.announcementsService.findByMasjidWithReadCounts(masjidId);
  }

  @Get()
  @ApiOperation({ summary: 'List published announcements for a masjid' })
  async getAnnouncements(@Param('masjidId') masjidId: string) {
    return this.announcementsService.findByMasjid(masjidId);
  }

  @Post()
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.ANNOUNCEMENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create and broadcast an announcement for a masjid' })
  async createAnnouncement(
    @Param('masjidId') masjidId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateAnnouncementDto,
  ) {
    return this.announcementsService.create(masjidId, userId, dto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.ANNOUNCEMENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Edit a masjid announcement' })
  async updateAnnouncement(
    @Param('masjidId') masjidId: string,
    @Param('id') id: string,
    @Body() dto: UpdateAnnouncementDto,
  ) {
    return this.announcementsService.update(masjidId, id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.ANNOUNCEMENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete an announcement' })
  async deleteAnnouncement(@Param('masjidId') masjidId: string, @Param('id') id: string) {
    return this.announcementsService.delete(masjidId, id);
  }
}
