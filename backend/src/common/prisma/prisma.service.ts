import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

let SUPABASE_DB_URL =
  process.env.DATABASE_URL ||
  process.env.DIRECT_URL ||
  'postgresql://postgres.eojasudtbpgwwtivcvbs:Tickora%401234@aws-1-ap-northeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true';

if (SUPABASE_DB_URL.includes('.pooler.supabase.com:5432')) {
  SUPABASE_DB_URL = SUPABASE_DB_URL.replace(':5432', ':6543');
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      datasources: {
        db: {
          url: SUPABASE_DB_URL,
        },
      },
    });
  }

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('✓ Prisma connected successfully to Supabase database (silah-db).');
    } catch (error) {
      this.logger.error('Failed to connect to database during startup:', error);
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
