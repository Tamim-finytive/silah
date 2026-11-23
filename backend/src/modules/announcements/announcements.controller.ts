import { Controller, Get, Post, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AnnouncementsService } from './announcements.service';
import { CreateAnnouncementDto, BroadcastAnnouncementDto } from './dto/announcement.dto';
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

  @Delete(':id')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN, RoleType.ANNOUNCEMENT)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete an announcement' })
  async deleteAnnouncement(@Param('masjidId') masjidId: string, @Param('id') id: string) {
    return this.announcementsService.delete(masjidId, id);
  }
}
