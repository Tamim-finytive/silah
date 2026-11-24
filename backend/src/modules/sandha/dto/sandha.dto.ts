import { IsNotEmpty, IsString, IsOptional, IsNumber, IsEnum, Matches, Min, MaxLength, IsIn } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { SandhaFrequency, PaymentMethod } from '@prisma/client';

export class CreateSandhaPlanDto {
  @ApiProperty({ example: 'மாதாந்திர சந்தா / Monthly Maintenance' })
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiProperty({ example: 200.00 })
  @IsNotEmpty()
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiProperty({ enum: SandhaFrequency, example: 'MONTHLY' })
  @IsNotEmpty()
  @IsEnum(SandhaFrequency)
  frequency: SandhaFrequency;

  @ApiPropertyOptional({ example: 'General maintenance fund' })
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: 'masjid.pay@bank' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  @Matches(/^[^\s@]+@[^\s@]+$/, { message: 'Enter a valid UPI ID' })
  upiId?: string;

  @ApiPropertyOptional({ example: 'Jamia Masjid' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  payeeName?: string;

  @ApiPropertyOptional({ example: '+919876543210' })
  @IsOptional()
  @IsString()
  @Matches(/^\+[1-9]\d{6,14}$/)
  contactPhone?: string;
}

export class EnrollMemberDto {
  @ApiProperty({ example: '+919876543213', description: 'Member phone number (auto-link key)' })
  @IsNotEmpty()
  @IsString()
  @Matches(/^\+[1-9]\d{6,14}$/)
  phone: string;

  @ApiProperty({ example: 'Abdul Rahman' })
  @IsNotEmpty()
  @IsString()
  name: string;
}

export class RecordPaymentDto {
  @ApiProperty({ example: 'uuid-of-plan-member' })
  @IsNotEmpty()
  @IsString()
  planMemberId: string;

  @ApiProperty({ example: 200.00 })
  @IsNotEmpty()
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiPropertyOptional({ enum: PaymentMethod, default: 'CASH' })
  @IsOptional()
  @IsEnum(PaymentMethod)
  method?: PaymentMethod;

  @ApiPropertyOptional({ example: 'REC-2026-001' })
  @IsOptional()
  @IsString()
  receiptNumber?: string;

  @ApiProperty({ example: '2026-11-01' })
  @IsNotEmpty()
  @IsString()
  periodStart: string;

  @ApiProperty({ example: '2026-11-30' })
  @IsNotEmpty()
  @IsString()
  periodEnd: string;

  @ApiPropertyOptional({ example: 'Paid in cash at Jummah' })
  @IsOptional()
  @IsString()
  notes?: string;
}

export class SubmitPaymentProofDto {
  @ApiProperty({ example: 'uuid-of-plan-member' })
  @IsNotEmpty()
  @IsString()
  planMemberId: string;

  @ApiProperty({ example: 500 })
  @IsNumber()
  @Min(0.01)
  amount: number;

  @ApiProperty({ example: '2026-11-01' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  periodStart: string;

  @ApiProperty({ example: '2026-11-30' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  periodEnd: string;

  @ApiProperty({ description: 'Private Supabase Storage object path returned by /uploads/sandha-proof' })
  @IsNotEmpty()
  @IsString()
  @MaxLength(500)
  proofPath: string;

  @ApiPropertyOptional({ example: 'UPI transaction reference' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  receiptNumber?: string;
}

export class ReviewPaymentDto {
  @ApiProperty({ enum: ['APPROVE', 'REJECT'] })
  @IsIn(['APPROVE', 'REJECT'])
  decision: 'APPROVE' | 'REJECT';

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
