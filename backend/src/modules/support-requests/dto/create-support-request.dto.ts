import { ApiProperty } from "@nestjs/swagger";
import {
  IsIn,
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength,
} from "class-validator";

export class CreateSupportRequestDto {
  @ApiProperty({ example: "Abdul Rahman" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  name: string;

  @ApiProperty({ example: "+919876543210" })
  @IsString()
  @IsNotEmpty()
  @Matches(/^(\+?[1-9]\d{6,14}|\d{10})$/)
  phone: string;

  @ApiProperty({ example: "Masjid admin access" })
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  subject: string;

  @ApiProperty({ example: "Please help me manage my local masjid." })
  @IsString()
  @IsNotEmpty()
  @MaxLength(4000)
  message: string;
}

export class UpdateSupportRequestStatusDto {
  @ApiProperty({ enum: ["OPEN", "IN_PROGRESS", "RESOLVED"] })
  @IsIn(["OPEN", "IN_PROGRESS", "RESOLVED"])
  status: "OPEN" | "IN_PROGRESS" | "RESOLVED";
}
