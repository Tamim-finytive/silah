import { IsOptional, IsString, IsEnum } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { Language } from '@prisma/client';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Janab Abdul Rahman' })
  @IsOptional()
  @IsString()
  name?: string;

  @ApiPropertyOptional({ enum: Language, example: 'ta' })
  @IsOptional()
  @IsEnum(Language)
  language?: Language;

  @ApiPropertyOptional({ example: 'https://cdn.masjidapp.com/avatars/user.jpg' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;
}
