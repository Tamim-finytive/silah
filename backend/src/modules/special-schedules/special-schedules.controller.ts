import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SpecialSchedulesService } from './special-schedules.service';
import { CreateSpecialScheduleDto } from './dto/special-schedule.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { MasjidRoleGuard } from '../../common/guards/masjid-role.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { MasjidRoles } from '../../common/decorators/roles.decorator';
import { RoleType } from '@prisma/client';

@ApiTags('Special Schedules')
@Controller('masjids/:masjidId/special-schedules')
export class SpecialSchedulesController {
  constructor(private readonly service: SpecialSchedulesService) {}

  @Get()
  @ApiOperation({ summary: 'List special schedules/events for a masjid (Public)' })
  async getSpecialSchedules(@Param('masjidId') masjidId: string) {
    return this.service.findByMasjid(masjidId);
  }

  @Post()
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create special schedule/event (Ramadan, Eid, Taraweeh) (Admin only)' })
  async createSpecialSchedule(
    @Param('masjidId') masjidId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateSpecialScheduleDto,
  ) {
    return this.service.create(masjidId, userId, dto);
  }

  @Put(':id')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update a masjid special schedule/event (Admin only)' })
  async updateSpecialSchedule(
    @Param('masjidId') masjidId: string,
    @Param('id') id: string,
    @Body() dto: CreateSpecialScheduleDto,
  ) {
    return this.service.update(masjidId, id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, MasjidRoleGuard)
  @MasjidRoles(RoleType.ADMIN)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete a special schedule/event (Admin only)' })
  async deleteSpecialSchedule(
    @Param('masjidId') masjidId: string,
    @Param('id') id: string,
  ) {
    return this.service.delete(masjidId, id);
  }
}
