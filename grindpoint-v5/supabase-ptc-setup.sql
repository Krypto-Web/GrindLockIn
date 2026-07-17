-- ================================================================
-- GRINDPOINT — PTC, Surf & Payment Proofs Setup
-- Run in Supabase → SQL Editor → New Query → RUN
-- ================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='last_login_date') THEN
    ALTER TABLE public.profiles ADD COLUMN last_login_date DATE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='login_streak') THEN
    ALTER TABLE public.profiles ADD COLUMN login_streak INT NOT NULL DEFAULT 0;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.ptc_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  ad_id TEXT NOT NULL,
  reward NUMERIC NOT NULL DEFAULT 0,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  view_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ptc_user_ad_date ON public.ptc_views(user_id,ad_id,view_date);
CREATE INDEX IF NOT EXISTS idx_ptc_user ON public.ptc_views(user_id);
ALTER TABLE public.ptc_views ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='ptc_views'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.ptc_views',pol.policyname); END LOOP;
END $$;
CREATE POLICY "ptc_insert_own" ON public.ptc_views FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "ptc_select_own" ON public.ptc_views FOR SELECT USING (auth.uid()=user_id OR public.is_admin());
CREATE POLICY "ptc_admin_all"  ON public.ptc_views FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE TABLE IF NOT EXISTS public.surf_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  site_id TEXT NOT NULL,
  reward NUMERIC NOT NULL DEFAULT 0,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  view_date DATE NOT NULL DEFAULT CURRENT_DATE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_surf_user_site_date ON public.surf_views(user_id,site_id,view_date);
ALTER TABLE public.surf_views ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='surf_views'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.surf_views',pol.policyname); END LOOP;
END $$;
CREATE POLICY "surf_insert_own" ON public.surf_views FOR INSERT WITH CHECK (auth.uid()=user_id);
CREATE POLICY "surf_select_own" ON public.surf_views FOR SELECT USING (auth.uid()=user_id OR public.is_admin());
CREATE POLICY "surf_admin_all"  ON public.surf_views FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

CREATE TABLE IF NOT EXISTS public.payment_proofs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_name TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  method TEXT DEFAULT 'Bank Transfer',
  proof_url TEXT,
  note TEXT,
  paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.payment_proofs ENABLE ROW LEVEL SECURITY;
DO $$ DECLARE pol RECORD; BEGIN
  FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='payment_proofs'
  LOOP EXECUTE format('DROP POLICY IF EXISTS %I ON public.payment_proofs',pol.policyname); END LOOP;
END $$;
CREATE POLICY "proofs_read_all"  ON public.payment_proofs FOR SELECT USING (true);
CREATE POLICY "proofs_admin_all" ON public.payment_proofs FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

INSERT INTO public.site_settings(key,value) VALUES('min_withdrawal','10000')
ON CONFLICT(key) DO UPDATE SET value='10000';

DO $$
BEGIN
  RAISE NOTICE '=== GRINDPOINT PTC SETUP ===';
  RAISE NOTICE 'ptc_views table: ready';
  RAISE NOTICE 'surf_views table: ready';
  RAISE NOTICE 'payment_proofs table: ready';
  RAISE NOTICE 'Min withdrawal: 10000';
  RAISE NOTICE '============================';
END $$;
