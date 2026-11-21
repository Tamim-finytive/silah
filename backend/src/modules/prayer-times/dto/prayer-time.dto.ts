import { IsNotEmpty, IsString, IsOptional, Matches } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UpdatePrayerTimeDto {
  @ApiProperty({ example: '2026-11-20', description: 'Date in YYYY-MM-DD format' })
  @IsNotEmpty()
  @IsString()
  date: string;

  @ApiPropertyOptional({ example: '05:00' })
  @IsOptional()
  @IsString()
  fajrAdhan?: string;

  @ApiPropertyOptional({ example: '05:30' })
  @IsOptional()
  @IsString()
  fajrJamaah?: string;

  @ApiPropertyOptional({ example: '06:05' })
  @IsOptional()
  @IsString()
  sunrise?: string;

  @ApiPropertyOptional({ example: '12:30' })
  @IsOptional()
  @IsString()
  dhuhrAdhan?: string;

  @ApiPropertyOptional({ example: '13:15' })
  @IsOptional()
  @IsString()
  dhuhrJamaah?: string;

  @ApiPropertyOptional({ example: '16:15' })
  @IsOptional()
  @IsString()
  asrAdhan?: string;

  @ApiPropertyOptional({ example: '16:45' })
  @IsOptional()
  @IsString()
  asrJamaah?: string;

  @ApiPropertyOptional({ example: '18:15' })
  @IsOptional()
  @IsString()
  sunset?: string;

  @ApiPropertyOptional({ example: '18:15' })
  @IsOptional()
  @IsString()
  maghribAdhan?: string;

  @ApiPropertyOptional({ example: '18:20' })
  @IsOptional()
  @IsString()
  maghribJamaah?: string;

  @ApiPropertyOptional({ example: '19:45' })
  @IsOptional()
  @IsString()
  ishaAdhan?: string;

  @ApiPropertyOptional({ example: '20:15' })
  @IsOptional()
  @IsString()
  ishaJamaah?: string;

  @ApiPropertyOptional({ example: '12:45' })
  @IsOptional()
  @IsString()
  jummahKhutbah?: string;

  @ApiPropertyOptional({ example: '13:30' })
  @IsOptional()
  @IsString()
  jummahJamaah?: string;
}

export class UpdatePrayerTimeRangeDto {
  @ApiProperty({ example: '2026-11-20', description: 'Start date in YYYY-MM-DD format' })
  @IsNotEmpty()
  @IsString()
  startDate: string;

  @ApiProperty({ example: '2026-11-30', description: 'End date in YYYY-MM-DD format' })
  @IsNotEmpty()
  @IsString()
  endDate: string;

  @ApiPropertyOptional({ example: '05:00' })
  @IsOptional()
  @IsString()
  fajrAdhan?: string;

  @ApiProperty({ example: '05:30' })
  @IsNotEmpty()
  @IsString()
  fajrJamaah: string;

  @ApiPropertyOptional({ example: '06:05' })
  @IsOptional()
  @IsString()
  sunrise?: string;

  @ApiPropertyOptional({ example: '12:30' })
  @IsOptional()
  @IsString()
  dhuhrAdhan?: string;

  @ApiProperty({ example: '13:15' })
  @IsNotEmpty()
  @IsString()
  dhuhrJamaah: string;

  @ApiPropertyOptional({ example: '16:15' })
  @IsOptional()
  @IsString()
  asrAdhan?: string;

  @ApiProperty({ example: '16:45' })
  @IsNotEmpty()
  @IsString()
  asrJamaah: string;

  @ApiPropertyOptional({ example: '18:15' })
  @IsOptional()
  @IsString()
  sunset?: string;

  @ApiPropertyOptional({ example: '18:15' })
  @IsOptional()
  @IsString()
  maghribAdhan?: string;

  @ApiProperty({ example: '18:20' })
  @IsNotEmpty()
  @IsString()
  maghribJamaah: string;

  @ApiPropertyOptional({ example: '19:45' })
  @IsOptional()
  @IsString()
  ishaAdhan?: string;

  @ApiProperty({ example: '20:15' })
  @IsNotEmpty()
  @IsString()
  ishaJamaah: string;

  @ApiPropertyOptional({ example: '12:45' })
  @IsOptional()
  @IsString()
  jummahKhutbah?: string;

  @ApiPropertyOptional({ example: '13:30' })
  @IsOptional()
  @IsString()
  jummahJamaah?: string;
}
