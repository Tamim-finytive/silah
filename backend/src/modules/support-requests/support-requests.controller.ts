import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { CurrentUser } from "../../common/decorators/current-user.decorator";
import { Roles } from "../../common/decorators/roles.decorator";
import { JwtAuthGuard } from "../../common/guards/jwt-auth.guard";
import { RolesGuard } from "../../common/guards/roles.guard";
import {
  CreateSupportRequestDto,
  UpdateSupportRequestStatusDto,
} from "./dto/create-support-request.dto";
import { SupportRequestsService } from "./support-requests.service";

@ApiTags("Support Requests")
@Controller("support-requests")
export class SupportRequestsController {
  constructor(private readonly supportRequests: SupportRequestsService) {}

  @Post()
  @ApiOperation({
    summary: "Submit a Contact Us request for Super Admin review",
  })
  create(@Body() dto: CreateSupportRequestDto) {
    return this.supportRequests.create(dto);
  }

  @Get("admin")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN")
  @ApiBearerAuth()
  @ApiOperation({ summary: "List Contact Us requests for Super Admin" })
  list(
    @Query("status") status?: string,
    @Query("page", new ParseIntPipe({ optional: true })) page?: number,
    @Query("limit", new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.supportRequests.list({ status, page, limit });
  }

  @Patch("admin/:id/status")
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles("SUPER_ADMIN")
  @ApiBearerAuth()
  @ApiOperation({ summary: "Update the status of a Contact Us request" })
  updateStatus(
    @Param("id") id: string,
    @CurrentUser("id") userId: string,
    @Body() dto: UpdateSupportRequestStatusDto,
  ) {
    return this.supportRequests.updateStatus(id, userId, dto.status);
  }
}
