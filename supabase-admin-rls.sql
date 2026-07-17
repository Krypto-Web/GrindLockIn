-- ============================================================
-- GRINDPOINT — Admin RLS Fix
-- Run this in Supabase → SQL Editor → New Query → RUN
-- Adds admin-level policies so the admin panel can write to all tables
-- ============================================================

-- ─── Helper function: is current user an admin? ──────────────
-- We use a SECURITY DEFINER function to safely check the role
-- without causing infinite recursion in RLS policies
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ─── PROFILES: admin can read/update/delete all rows ─────────
DROP POLICY IF EXISTS "admin_profiles_all" ON public.profiles;
CREATE POLICY "admin_profiles_all"
  ON public.profiles FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── TASK SUBMISSIONS: admin can read/update all rows ────────
DROP POLICY IF EXISTS "admin_task_sub_all" ON public.task_submissions;
CREATE POLICY "admin_task_sub_all"
  ON public.task_submissions FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── WITHDRAWAL REQUESTS: admin can read/update all rows ─────
DROP POLICY IF EXISTS "admin_wr_all" ON public.withdrawal_requests;
CREATE POLICY "admin_wr_all"
  ON public.withdrawal_requests FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── ANNOUNCEMENTS: admin can do everything ──────────────────
DROP POLICY IF EXISTS "admin_ann_all" ON public.announcements;
CREATE POLICY "admin_ann_all"
  ON public.announcements FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── SITE SETTINGS: admin can read/write ─────────────────────
DROP POLICY IF EXISTS "admin_ss_all" ON public.site_settings;
CREATE POLICY "admin_ss_all"
  ON public.site_settings FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── TASKS TABLE: admin can add/edit/delete tasks ────────────
DROP POLICY IF EXISTS "admin_tasks_all" ON public.tasks;
CREATE POLICY "admin_tasks_all"
  ON public.tasks FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── COMPLETED TASKS: admin can view all ─────────────────────
DROP POLICY IF EXISTS "admin_ct_all" ON public.completed_tasks;
CREATE POLICY "admin_ct_all"
  ON public.completed_tasks FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─── Verify ──────────────────────────────────────────────────
DO $$
DECLARE
  fn_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'is_admin'
  ) INTO fn_exists;

  IF fn_exists THEN
    RAISE NOTICE '✅ is_admin() function created successfully';
    RAISE NOTICE '✅ Admin RLS policies applied to all tables';
    RAISE NOTICE '';
    RAISE NOTICE 'Admin panel should now be fully functional.';
  ELSE
    RAISE WARNING '⚠️  Something went wrong — is_admin() not found';
  END IF;
END $$;
