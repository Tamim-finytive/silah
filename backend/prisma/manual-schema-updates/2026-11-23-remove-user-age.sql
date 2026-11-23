-- Run against the existing PostgreSQL database after deploying the age-free backend.
-- Existing age values are intentionally discarded per the project owner's request.
ALTER TABLE public.users DROP COLUMN IF EXISTS age;
