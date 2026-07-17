-- ============================================================
-- GRINDPOINT — supabase-fix.sql  (v3 — Safe to re-run)
-- 
-- Run in: Supabase → SQL Editor → New Query → Paste → RUN
-- This script is fully idempotent — safe to run multiple times.
-- ============================================================

-- ─── 1. Drop any broken trigger ─────────────────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- ─── 2. profiles table ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id              UUID        NOT NULL PRIMARY KEY,
  full_name       TEXT,
  email           TEXT,
  phone           TEXT,
  state           TEXT,
  balance         NUMERIC     NOT NULL DEFAULT 0,
  tasks_completed INT         NOT NULL DEFAULT 0,
  referral_count  INT         NOT NULL DEFAULT 0,
  referrer_id     UUID,
  role            TEXT        NOT NULL DEFAULT 'user',
  status          TEXT        NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- FK to auth.users (safe — skipped if already exists)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'profiles_id_fkey'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_id_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ─── 3. Auto-create profile on signup trigger ────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (
    id, full_name, email, phone, state, referrer_id,
    balance, tasks_completed, referral_count, role, status, created_at, updated_at
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'state', ''),
    CASE
      WHEN (NEW.raw_user_meta_data->>'referrer_id') IS NOT NULL
       AND (NEW.raw_user_meta_data->>'referrer_id') <> ''
      THEN (NEW.raw_user_meta_data->>'referrer_id')::UUID
      ELSE NULL
    END,
    0, 0, 0, 'user', 'active', NOW(), NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── 4. RLS for profiles ─────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies first (idempotent)
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

CREATE POLICY "profiles_public_read"   ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own"    ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own"    ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_delete_own"    ON public.profiles FOR DELETE USING (auth.uid() = id);

-- ─── 5. completed_tasks ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.completed_tasks (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  task_id      TEXT        NOT NULL,
  reward       NUMERIC     NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_completed_tasks_user ON public.completed_tasks(user_id);

ALTER TABLE public.completed_tasks ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'completed_tasks'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.completed_tasks', pol.policyname); END LOOP;
END $$;
CREATE POLICY "ct_insert_own" ON public.completed_tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ct_select_own" ON public.completed_tasks FOR SELECT USING (auth.uid() = user_id);

-- ─── 6. task_submissions ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.task_submissions (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  task_id      TEXT        NOT NULL,
  task_title   TEXT,
  reward       NUMERIC     NOT NULL DEFAULT 0,
  proof_url    TEXT,
  note         TEXT,
  status       TEXT        NOT NULL DEFAULT 'pending',
  admin_note   TEXT,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_task_sub_user   ON public.task_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_task_sub_status ON public.task_submissions(status);

ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'task_submissions'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.task_submissions', pol.policyname); END LOOP;
END $$;
CREATE POLICY "ts_insert_own" ON public.task_submissions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ts_select_own" ON public.task_submissions FOR SELECT USING (auth.uid() = user_id);

-- ─── 7. withdrawal_requests ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id             UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount         NUMERIC     NOT NULL,
  method         TEXT        DEFAULT 'bank_transfer',
  bank_name      TEXT,
  account_number TEXT,
  account_name   TEXT,
  phone_number   TEXT,
  status         TEXT        NOT NULL DEFAULT 'pending',
  admin_note     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_wr_user   ON public.withdrawal_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_wr_status ON public.withdrawal_requests(status);

ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'withdrawal_requests'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.withdrawal_requests', pol.policyname); END LOOP;
END $$;
CREATE POLICY "wr_insert_own" ON public.withdrawal_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "wr_select_own" ON public.withdrawal_requests FOR SELECT USING (auth.uid() = user_id);

-- ─── 8. announcements ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title      TEXT        NOT NULL,
  body       TEXT,
  type       TEXT        DEFAULT 'info',
  is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'announcements'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.announcements', pol.policyname); END LOOP;
END $$;
CREATE POLICY "ann_select_all" ON public.announcements FOR SELECT USING (true);

-- ─── 9. site_settings ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.site_settings (
  key        TEXT        PRIMARY KEY,
  value      TEXT        NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'site_settings'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.site_settings', pol.policyname); END LOOP;
END $$;
CREATE POLICY "ss_select_all" ON public.site_settings FOR SELECT USING (true);

INSERT INTO public.site_settings (key, value) VALUES
  ('min_withdrawal',          '1000'),
  ('referral_bonus_starter',  '200'),
  ('referral_bonus_hustler',  '300'),
  ('referral_bonus_champion', '500'),
  ('registration_open',       'true'),
  ('withdrawals_enabled',     'true'),
  ('referral_active',         'true'),
  ('maintenance_mode',        'false')
ON CONFLICT (key) DO NOTHING;

-- ─── 10. Storage bucket for task proofs ─────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('task-proofs', 'task-proofs', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "task_proofs_upload"      ON storage.objects;
DROP POLICY IF EXISTS "task_proofs_public_read" ON storage.objects;

CREATE POLICY "task_proofs_upload"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'task-proofs' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "task_proofs_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'task-proofs');

-- ─── 11. Verification ───────────────────────────────────────
DO $$ DECLARE trigger_ok BOOLEAN; profiles_ok BOOLEAN; submissions_ok BOOLEAN;
BEGIN
  SELECT EXISTS(SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'on_auth_user_created'
      AND event_object_schema = 'auth') INTO trigger_ok;
  SELECT EXISTS(SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'profiles') INTO profiles_ok;
  SELECT EXISTS(SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'task_submissions') INTO submissions_ok;

  IF trigger_ok AND profiles_ok AND submissions_ok THEN
    RAISE NOTICE '';
    RAISE NOTICE '✅ SUCCESS — All tables and trigger are correctly configured.';
    RAISE NOTICE '✅ Users can now register, complete tasks, and withdraw funds.';
    RAISE NOTICE '';
    RAISE NOTICE 'NEXT STEP: Promote yourself to admin by running:';
    RAISE NOTICE 'UPDATE public.profiles SET role = ''admin'' WHERE email = ''YOUR@EMAIL.com'';';
  ELSE
    RAISE WARNING 'trigger_ok=%, profiles_ok=%, submissions_ok=%', trigger_ok, profiles_ok, submissions_ok;
  END IF;
END $$;

-- ─── ADDITION: tasks table (admin-editable task definitions) ──
-- Required for Task Manager (admin/tasks-admin.html) to save edits

CREATE TABLE IF NOT EXISTS public.tasks (
  id           TEXT        PRIMARY KEY,
  title        TEXT        NOT NULL,
  description  TEXT,
  category     TEXT        NOT NULL DEFAULT 'social',
  icon         TEXT        DEFAULT '⚡',
  reward       NUMERIC     NOT NULL DEFAULT 0,
  duration     TEXT        DEFAULT '—',
  link         TEXT,
  instructions JSONB       DEFAULT '[]'::jsonb,
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  sort_order   INT         DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (idempotent)
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'tasks'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.tasks', pol.policyname); END LOOP;
END $$;

-- Everyone can read active tasks (needed for the public tasks.html page)
CREATE POLICY "tasks_public_read"
  ON public.tasks FOR SELECT
  USING (is_active = TRUE);

-- Admin RLS policy for this table is added separately in supabase-admin-rls.sql
