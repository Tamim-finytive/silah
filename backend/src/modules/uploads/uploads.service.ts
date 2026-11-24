import { Injectable, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../../common/prisma/prisma.service';

export interface FileUploadPayload {
  originalname: string;
  buffer: Buffer;
  mimetype: string;
  size: number;
}

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(private readonly config: ConfigService, private readonly prisma: PrismaService) {}

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

  async uploadSandhaProof(
    file: FileUploadPayload,
    masjidId: string,
    userId: string,
  ): Promise<{ path: string; signedUrl: string; size: number; mimeType: string }> {
    const enrollment = await this.prisma.sandhaPlanMember.findFirst({
      where: { userId, plan: { masjidId, isActive: true } },
      select: { id: true },
    });
    if (!enrollment) {
      throw new ForbiddenException('Join an active Sandha plan before uploading a payment screenshot.');
    }
    if (!file?.buffer || !['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      throw new BadRequestException('Upload a JPG, PNG, or WEBP payment screenshot.');
    }
    if (file.size > 8 * 1024 * 1024) {
      throw new BadRequestException('Payment screenshot must be 8 MB or smaller.');
    }
    const supabaseUrl = this.config.get<string>('SUPABASE_URL') || process.env.SUPABASE_URL;
    const supabaseKey = this.config.get<string>('SUPABASE_SECRET_KEY') || process.env.SUPABASE_SECRET_KEY;
    if (!supabaseUrl || !supabaseKey) {
      throw new BadRequestException('Private storage configuration is missing on the server.');
    }

    const extension = file.mimetype === 'image/png' ? 'png' : file.mimetype === 'image/webp' ? 'webp' : 'jpg';
    const path = `sandha-proofs/${masjidId}/${userId}/${uuidv4()}.${extension}`;
    const encodedPath = path.split('/').map(encodeURIComponent).join('/');
    const bucket = 'silah-private';
    const uploadResponse = await fetch(
      `${supabaseUrl}/storage/v1/object/${bucket}/${encodedPath}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${supabaseKey}`,
          apikey: supabaseKey,
          'Content-Type': file.mimetype,
          'x-upsert': 'false',
        },
        body: file.buffer as any,
      },
    );
    if (!uploadResponse.ok) {
      const message = await uploadResponse.text();
      this.logger.error(`Private Sandha proof upload failed (${uploadResponse.status}).`);
      throw new BadRequestException(`Payment screenshot upload failed: ${message}`);
    }

    return {
      path,
      signedUrl: await this.createSandhaProofSignedUrl(path),
      size: file.size,
      mimeType: file.mimetype,
    };
  }

  async createSandhaProofSignedUrl(path: string): Promise<string> {
    if (!path.startsWith('sandha-proofs/')) {
      throw new BadRequestException('Invalid payment proof path.');
    }
    const supabaseUrl = this.config.get<string>('SUPABASE_URL') || process.env.SUPABASE_URL;
    const supabaseKey = this.config.get<string>('SUPABASE_SECRET_KEY') || process.env.SUPABASE_SECRET_KEY;
    if (!supabaseUrl || !supabaseKey) {
      throw new BadRequestException('Private storage configuration is missing on the server.');
    }
    const encodedPath = path.split('/').map(encodeURIComponent).join('/');
    const response = await fetch(
      `${supabaseUrl}/storage/v1/object/sign/silah-private/${encodedPath}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${supabaseKey}`,
          apikey: supabaseKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ expiresIn: 3600 }),
      },
    );
    if (!response.ok) {
      const message = await response.text();
      this.logger.error(`Private Sandha proof signing failed (${response.status}).`);
      throw new BadRequestException('Payment proof is stored but could not be opened right now.');
    }
    const result = await response.json() as { signedURL?: string; signedUrl?: string };
    const signedPath = result.signedURL ?? result.signedUrl;
    if (!signedPath) throw new BadRequestException('Storage did not return a signed proof link.');
    return signedPath.startsWith('http') ? signedPath : `${supabaseUrl}/storage/v1${signedPath}`;
  }
}
