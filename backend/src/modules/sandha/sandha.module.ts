import { Module } from '@nestjs/common';
import { SandhaController } from './sandha.controller';
import { SandhaService } from './sandha.service';
import { UploadsModule } from '../uploads/uploads.module';

@Module({
  imports: [UploadsModule],
  controllers: [SandhaController],
  providers: [SandhaService],
  exports: [SandhaService],
})
export class SandhaModule {}
