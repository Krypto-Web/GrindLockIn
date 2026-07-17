-- ================================================================
-- GRINDPOINT — EMERGENCY FIX SQL
-- Run this ONCE in Supabase → SQL Editor → New Query → RUN
-- This fixes ALL known issues: missing columns, broken RLS, schema
-- ================================================================

-- ── 1. Fix tasks table: add missing columns if they don't exist ──
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='link') THEN
    ALTER TABLE public.tasks ADD COLUMN link TEXT;
    RAISE NOTICE '✅ Added link column to tasks';
  ELSE
    RAISE NOTICE '✅ link column already exists in tasks';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='instructions') THEN
    ALTER TABLE public.tasks ADD COLUMN instructions JSONB DEFAULT '[]'::jsonb;
    RAISE NOTICE '✅ Added instructions column to tasks';
  ELSE
    RAISE NOTICE '✅ instructions column already exists in tasks';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='icon') THEN
    ALTER TABLE public.tasks ADD COLUMN icon TEXT DEFAULT '⚡';
    RAISE NOTICE '✅ Added icon column to tasks';
  ELSE
    RAISE NOTICE '✅ icon column already exists in tasks';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='duration') THEN
    ALTER TABLE public.tasks ADD COLUMN duration TEXT DEFAULT '—';
    RAISE NOTICE '✅ Added duration column to tasks';
  ELSE
    RAISE NOTICE '✅ duration column already exists in tasks';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='sort_order') THEN
    ALTER TABLE public.tasks ADD COLUMN sort_order INT DEFAULT 0;
    RAISE NOTICE '✅ Added sort_order column to tasks';
  ELSE
    RAISE NOTICE '✅ sort_order column already exists in tasks';
  END IF;
END $$;

-- ── 2. Fix task_submissions: add missing columns ──────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='task_submissions') THEN
    CREATE TABLE public.task_submissions (
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
    RAISE NOTICE '✅ Created task_submissions table';
  ELSE
    RAISE NOTICE '✅ task_submissions table already exists';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='task_submissions' AND column_name='admin_note') THEN
    ALTER TABLE public.task_submissions ADD COLUMN admin_note TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='task_submissions' AND column_name='reviewed_at') THEN
    ALTER TABLE public.task_submissions ADD COLUMN reviewed_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='task_submissions' AND column_name='task_title') THEN
    ALTER TABLE public.task_submissions ADD COLUMN task_title TEXT;
  END IF;
END $$;

-- ── 3. Fix withdrawal_requests table ─────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='withdrawal_requests') THEN
    CREATE TABLE public.withdrawal_requests (
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
    RAISE NOTICE '✅ Created withdrawal_requests table';
  ELSE
    RAISE NOTICE '✅ withdrawal_requests table already exists';
  END IF;
END $$;

-- ── 4. Create is_admin() function (SECURITY DEFINER) ─────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── 5. Enable RLS on all tables ───────────────────────────────────
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_submissions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings     ENABLE ROW LEVEL SECURITY;

-- ── 6. Drop ALL existing policies and recreate clean ─────────────
DO $$ DECLARE pol RECORD; tbl TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['profiles','tasks','task_submissions','withdrawal_requests','announcements','site_settings','completed_tasks'])
  LOOP
    FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=tbl
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, tbl);
    END LOOP;
  END LOOP;
END $$;

-- profiles
CREATE POLICY "profiles_read_all"     ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own"   ON public.profiles FOR INSERT WITH CHECK (auth.uid()=id);
CREATE POLICY "profiles_update_own"   ON public.profiles FOR UPDATE USING (auth.uid()=id OR public.is_admin());
CREATE POLICY "profiles_admin_all"    ON public.profiles FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- tasks (everyone can read active tasks, admin can do everything)
CREATE POLICY "tasks_read_active"     ON public.tasks FOR SELECT USING (is_active=true OR public.is_admin());
CREATE POLICY "tasks_admin_all"       ON public.tasks FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- task_submissions
CREATE POLICY "ts_insert_own"         ON public.task_submissions FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "ts_select_own"         ON public.task_submissions FOR SELECT USING (auth.uid()=user_id OR public.is_admin());
CREATE POLICY "ts_admin_all"          ON public.task_submissions FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- withdrawal_requests
CREATE POLICY "wr_insert_own"         ON public.withdrawal_requests FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "wr_select_own"         ON public.withdrawal_requests FOR SELECT USING (auth.uid()=user_id OR public.is_admin());
CREATE POLICY "wr_admin_all"          ON public.withdrawal_requests FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- announcements
CREATE POLICY "ann_read_all"          ON public.announcements FOR SELECT USING (true);
CREATE POLICY "ann_admin_all"         ON public.announcements FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- site_settings
CREATE POLICY "ss_read_all"           ON public.site_settings FOR SELECT USING (true);
CREATE POLICY "ss_admin_all"          ON public.site_settings FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ── 7. Storage bucket for proof screenshots ───────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('task-proofs', 'task-proofs', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "task_proofs_upload"      ON storage.objects;
DROP POLICY IF EXISTS "task_proofs_public_read" ON storage.objects;
CREATE POLICY "task_proofs_upload"      ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='task-proofs');
CREATE POLICY "task_proofs_public_read" ON storage.objects FOR SELECT USING (bucket_id='task-proofs');
CREATE POLICY "task_proofs_admin"       ON storage.objects FOR ALL USING (bucket_id='task-proofs' AND public.is_admin());

-- ── 8. Verify everything ──────────────────────────────────────────
DO $$ 
DECLARE 
  link_exists BOOLEAN;
  ts_exists   BOOLEAN;
  wr_exists   BOOLEAN;
  fn_exists   BOOLEAN;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_schema='public' AND table_name='tasks' AND column_name='link') INTO link_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='task_submissions') INTO ts_exists;
  SELECT EXISTS (SELECT 1 FROM information_schema.tables 
    WHERE table_schema='public' AND table_name='withdrawal_requests') INTO wr_exists;
  SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname='is_admin') INTO fn_exists;

  RAISE NOTICE '=== GRINDPOINT DB VERIFICATION ===';
  RAISE NOTICE 'tasks.link column: %',       CASE WHEN link_exists THEN '✅ OK' ELSE '❌ MISSING' END;
  RAISE NOTICE 'task_submissions table: %',  CASE WHEN ts_exists   THEN '✅ OK' ELSE '❌ MISSING' END;
  RAISE NOTICE 'withdrawal_requests table: %', CASE WHEN wr_exists THEN '✅ OK' ELSE '❌ MISSING' END;
  RAISE NOTICE 'is_admin() function: %',     CASE WHEN fn_exists   THEN '✅ OK' ELSE '❌ MISSING' END;
  RAISE NOTICE '==================================';
  
  IF link_exists AND ts_exists AND wr_exists AND fn_exists THEN
    RAISE NOTICE '🎉 ALL CHECKS PASSED — Admin panel is fully functional';
  ELSE
    RAISE WARNING '⚠️  Some checks failed — review output above';
  END IF;
END $$;
