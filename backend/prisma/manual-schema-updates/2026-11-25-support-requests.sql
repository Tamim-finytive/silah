CREATE TYPE "SupportRequestStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED');

CREATE TABLE "support_requests" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" VARCHAR(100) NOT NULL,
  "phone" VARCHAR(20) NOT NULL,
  "subject" VARCHAR(160) NOT NULL,
  "message" TEXT NOT NULL,
  "status" "SupportRequestStatus" NOT NULL DEFAULT 'OPEN',
  "reviewed_by" UUID,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "support_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "support_requests_reviewed_by_fkey"
    FOREIGN KEY ("reviewed_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "idx_support_requests_status_created"
  ON "support_requests"("status", "created_at");
CREATE INDEX "idx_support_requests_phone_created"
  ON "support_requests"("phone", "created_at");

ALTER TABLE "support_requests" ENABLE ROW LEVEL SECURITY;
