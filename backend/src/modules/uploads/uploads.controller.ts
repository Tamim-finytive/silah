import {
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
  UseGuards,
  BadRequestException,
  Body,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { UploadsService, FileUploadPayload } from './uploads.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('Uploads')
@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploadsService: UploadsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Upload an image or audio file for announcements' })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        file: {
          type: 'string',
          format: 'binary',
        },
      },
    },
  })
  @UseInterceptors(
    FileInterceptor('file', {
      limits: {
        fileSize: 25 * 1024 * 1024, // 25 MB max
      },
    }),
  )
  async uploadFile(@UploadedFile() file: FileUploadPayload) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    const result = await this.uploadsService.uploadFile(file);
    return {
      success: true,
      data: result,
    };
  }

  @Post('sandha-proof')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Upload a private Sandha payment screenshot' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  async uploadSandhaProof(
    @UploadedFile() file: FileUploadPayload,
    @Body('masjidId') masjidId: string,
    @CurrentUser('id') userId: string,
  ) {
    if (!file) throw new BadRequestException('File is required');
    if (!masjidId) throw new BadRequestException('Masjid is required');
    const result = await this.uploadsService.uploadSandhaProof(
      file,
      masjidId,
      userId,
    );
    return { success: true, data: result };
  }
}
