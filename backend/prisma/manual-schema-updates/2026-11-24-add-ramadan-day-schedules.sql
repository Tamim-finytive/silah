BEGIN;

CREATE TABLE IF NOT EXISTS public.ramadan_day_schedules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  masjid_id uuid NOT NULL REFERENCES public.masjids(id) ON DELETE CASCADE,
  date date NOT NULL,
  sehri_end varchar(8) NOT NULL,
  iftar_time varchar(8) NOT NULL,
  notes text,
  created_by uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ramadan_day_schedules_masjid_id_date_key UNIQUE (masjid_id, date)
);

ALTER TABLE public.ramadan_day_schedules ENABLE ROW LEVEL SECURITY;

COMMIT;
