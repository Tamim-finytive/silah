import { Module } from '@nestjs/common';
import {
  BroadcastAnnouncementsController,
  MasjidAnnouncementsController,
} from './announcements.controller';
import { AnnouncementsService } from './announcements.service';

@Module({
  controllers: [BroadcastAnnouncementsController, MasjidAnnouncementsController],
  providers: [AnnouncementsService],
  exports: [AnnouncementsService],
})
export class AnnouncementsModule {}
