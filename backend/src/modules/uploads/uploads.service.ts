import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v4 as uuidv4 } from 'uuid';

export interface FileUploadPayload {
  originalname: string;
  buffer: Buffer;
  mimetype: string;
  size: number;
}

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(private readonly config: ConfigService) {}

  async uploadFile(file: FileUploadPayload, folder = 'announcements'): Promise<{ url: string; size: number; mimeType: string }> {
    if (!file || !file.buffer) {
      throw new BadRequestException('No file provided');
    }

    const supabaseUrl = this.config.get<string>('SUPABASE_URL') || process.env.SUPABASE_URL;
    const supabaseKey = this.config.get<string>('SUPABASE_SECRET_KEY') || process.env.SUPABASE_SECRET_KEY;

    if (!supabaseUrl || !supabaseKey) {
      throw new BadRequestException('Storage configuration missing in server');
    }

    // Determine extension
    const originalExt = file.originalname?.split('.').pop() || 'bin';
    const cleanExt = originalExt.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
    const fileName = `${Date.now()}_${uuidv4().substring(0, 8)}.${cleanExt}`;
    const storagePath = `${folder}/${fileName}`;

    try {
      const uploadUrl = `${supabaseUrl}/storage/v1/object/silah-media/${storagePath}`;
      const response = await fetch(uploadUrl, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${supabaseKey}`,
          apikey: supabaseKey,
          'Content-Type': file.mimetype || 'application/octet-stream',
        },
        body: file.buffer as any,
      });

      if (!response.ok) {
        const errorText = await response.text();
        this.logger.error(`Failed to upload file to Supabase Storage: ${response.status} - ${errorText}`);
        throw new BadRequestException(`Upload failed: ${errorText}`);
      }

      const publicUrl = `${supabaseUrl}/storage/v1/object/public/silah-media/${storagePath}`;
      this.logger.log(`Uploaded file to ${publicUrl}`);

      return {
        url: publicUrl,
        size: file.size,
        mimeType: file.mimetype,
      };
    } catch (err: any) {
      this.logger.error(`Error uploading file: ${err.message}`);
      throw new BadRequestException(err.message || 'File upload failed');
    }
  }
}
