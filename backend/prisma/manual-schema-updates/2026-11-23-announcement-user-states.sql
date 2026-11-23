CREATE TABLE IF NOT EXISTS public.announcement_user_states (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  read_at timestamptz,
  hidden_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT announcement_user_states_user_id_announcement_id_key
    UNIQUE (user_id, announcement_id)
);

CREATE INDEX IF NOT EXISTS idx_announcement_user_states_announcement_read
  ON public.announcement_user_states (announcement_id, read_at);

CREATE INDEX IF NOT EXISTS idx_announcement_user_states_user_hidden
  ON public.announcement_user_states (user_id, hidden_at);

ALTER TABLE public.announcement_user_states ENABLE ROW LEVEL SECURITY;
