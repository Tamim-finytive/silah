import { IsNotEmpty, IsString, IsOptional, Matches, IsArray, ValidateNested, ArrayMinSize, ArrayMaxSize } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

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
  @ApiProperty({ description: 'Start date, YYYY-MM-DD' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  startDate: string;

  @ApiPropertyOptional({ description: 'End date, YYYY-MM-DD; omit for an open-ended schedule' })
  @IsString()
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  endDate?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  sunrise?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  sunset?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  fajrAdhan?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  fajrJamaah: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  dhuhrAdhan?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  dhuhrJamaah: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  asrAdhan?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  asrJamaah: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  maghribAdhan?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  maghribJamaah: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  ishaAdhan?: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  ishaJamaah: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  jummahKhutbah?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  jummahJamaah?: string;
}

export class RamadanDayScheduleDto {
  @ApiProperty({ description: 'Local calendar date, YYYY-MM-DD' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date: string;

  @ApiProperty({ description: 'Last time to eat before fasting, HH:mm' })
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  sehriEnd: string;

  @ApiProperty({ description: 'Iftar time, HH:mm' })
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  iftarTime: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  notes?: string;
}

export class UpsertRamadanScheduleDto {
  @ApiProperty({ type: [RamadanDayScheduleDto], minItems: 1, maxItems: 31 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(31)
  @ValidateNested({ each: true })
  @Type(() => RamadanDayScheduleDto)
  days: RamadanDayScheduleDto[];
}
