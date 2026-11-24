BEGIN;

ALTER TYPE public."PaymentStatus" ADD VALUE IF NOT EXISTS 'REJECTED';

ALTER TABLE public.sandha_plans
  ADD COLUMN IF NOT EXISTS upi_id varchar(120),
  ADD COLUMN IF NOT EXISTS payee_name varchar(120),
  ADD COLUMN IF NOT EXISTS contact_phone varchar(20);

ALTER TABLE public.sandha_payments
  ADD COLUMN IF NOT EXISTS proof_path varchar(500),
  ADD COLUMN IF NOT EXISTS verified_at timestamptz(6),
  ADD COLUMN IF NOT EXISTS verified_by uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sandha_payments_verified_by_fkey'
      AND conrelid = 'public.sandha_payments'::regclass
  ) THEN
    ALTER TABLE public.sandha_payments
      ADD CONSTRAINT sandha_payments_verified_by_fkey
      FOREIGN KEY (verified_by) REFERENCES public.users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sandha_payments_month_status
  ON public.sandha_payments (plan_id, period_start, status);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'silah-private',
  'silah-private',
  false,
  8388608,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = 8388608,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::text[];

COMMIT;
