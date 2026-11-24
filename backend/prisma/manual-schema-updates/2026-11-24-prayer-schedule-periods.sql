-- Persistent date-range prayer schedules. A NULL end_date means the saved
-- timetable stays effective until a newer schedule replaces it.
CREATE TABLE IF NOT EXISTS public.prayer_schedule_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  masjid_id uuid NOT NULL REFERENCES public.masjids(id) ON DELETE CASCADE,
  start_date date NOT NULL,
  end_date date NULL,
  sunrise varchar(8),
  sunset varchar(8),
  fajr_adhan varchar(8),
  fajr_jamaah varchar(8) NOT NULL,
  dhuhr_adhan varchar(8),
  dhuhr_jamaah varchar(8) NOT NULL,
  asr_adhan varchar(8),
  asr_jamaah varchar(8) NOT NULL,
  maghrib_adhan varchar(8),
  maghrib_jamaah varchar(8) NOT NULL,
  isha_adhan varchar(8),
  isha_jamaah varchar(8) NOT NULL,
  jummah_khutbah varchar(8),
  jummah_jamaah varchar(8),
  updated_by uuid NOT NULL REFERENCES public.users(id),
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  updated_at timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT prayer_schedule_periods_valid_dates
    CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_prayer_schedule_periods_dates
  ON public.prayer_schedule_periods (masjid_id, start_date, end_date);

-- Silah accesses this table through the NestJS backend only. Do not expose it
-- through Supabase's Data API; the backend's database role performs access.
ALTER TABLE public.prayer_schedule_periods ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.prayer_schedule_periods FROM anon, authenticated;
