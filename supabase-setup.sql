-- ============================================================
-- GRINDPOINT — Complete Supabase Database Setup
-- Run this entire script in Supabase SQL Editor
-- Dashboard → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ─── 1. PROFILES TABLE ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id            UUID        REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name     TEXT,
  email         TEXT,
  phone         TEXT,
  state         TEXT,
  balance       NUMERIC     DEFAULT 0 NOT NULL,
  tasks_completed INT       DEFAULT 0 NOT NULL,
  referral_count  INT       DEFAULT 0 NOT NULL,
  referrer_id   UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  role          TEXT        DEFAULT 'user' NOT NULL,
  status        TEXT        DEFAULT 'active' NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─── 2. TASKS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tasks (
  id            TEXT        PRIMARY KEY,
  title         TEXT        NOT NULL,
  description   TEXT,
  category      TEXT        DEFAULT 'general',
  icon          TEXT        DEFAULT '⚡',
  icon_bg       TEXT,
  reward        NUMERIC     NOT NULL DEFAULT 100,
  duration      TEXT        DEFAULT '2 min',
  instructions  JSONB       DEFAULT '[]'::JSONB,
  is_active     BOOLEAN     DEFAULT TRUE NOT NULL,
  sort_order    INT         DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ─── 3. COMPLETED TASKS TABLE ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.completed_tasks (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  task_id       TEXT        NOT NULL,
  reward        NUMERIC     NOT NULL DEFAULT 0,
  completed_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_completed_tasks_user ON public.completed_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_completed_tasks_task  ON public.completed_tasks(task_id);

-- ─── 4. WITHDRAWAL REQUESTS TABLE ────────────────────────────
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount          NUMERIC     NOT NULL,
  method          TEXT        DEFAULT 'bank_transfer',
  bank_name       TEXT,
  account_number  TEXT,
  account_name    TEXT,
  phone_number    TEXT,
  status          TEXT        DEFAULT 'pending' NOT NULL,
  admin_note      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_withdrawals_user   ON public.withdrawal_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON public.withdrawal_requests(status);

-- ─── 5. ANNOUNCEMENTS TABLE ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT        NOT NULL,
  body        TEXT,
  type        TEXT        DEFAULT 'info',
  is_active   BOOLEAN     DEFAULT TRUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ─── 6. SITE SETTINGS TABLE ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.site_settings (
  key         TEXT        PRIMARY KEY,
  value       TEXT        NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Default settings
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

-- ─── 7. ROW LEVEL SECURITY ───────────────────────────────────

-- PROFILES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Leaderboard: everyone can read public profile fields
CREATE POLICY "profiles_select_leaderboard"
  ON public.profiles FOR SELECT
  USING (true);

-- COMPLETED TASKS
ALTER TABLE public.completed_tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "completed_tasks_insert_own"
  ON public.completed_tasks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "completed_tasks_select_own"
  ON public.completed_tasks FOR SELECT
  USING (auth.uid() = user_id);

-- WITHDRAWAL REQUESTS
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "withdrawals_insert_own"
  ON public.withdrawal_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "withdrawals_select_own"
  ON public.withdrawal_requests FOR SELECT
  USING (auth.uid() = user_id);

-- ANNOUNCEMENTS (public read)
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "announcements_select_active"
  ON public.announcements FOR SELECT
  USING (is_active = TRUE);

-- TASKS (public read for active tasks)
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tasks_select_active"
  ON public.tasks FOR SELECT
  USING (is_active = TRUE);

-- SITE SETTINGS (public read)
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_select_all"
  ON public.site_settings FOR SELECT
  USING (true);

-- ─── 8. SEED SAMPLE TASKS ────────────────────────────────────
INSERT INTO public.tasks (id, title, description, category, icon, reward, duration, instructions, sort_order) VALUES
  ('task_001','Follow Instagram Business Page','Follow a brand''s Instagram page and keep it for 7 days.','social','📱',250,'2 min','["Open the Instagram link","Click Follow","Do not unfollow within 7 days","Return here to claim reward"]',1),
  ('task_002','Watch & Rate Ad Video','Watch a 60-second product ad and give it a 5-star rating on YouTube.','video','🎬',180,'3 min','["Click the YouTube link","Watch the full video","Like and rate 5 stars","Return here to confirm"]',2),
  ('task_003','Complete Market Survey','Answer 10 quick questions about your shopping habits.','survey','📊',500,'5 min','["Click the survey link","Answer all 10 questions","Submit the form","Screenshot completion page"]',3),
  ('task_004','Like & Share Facebook Post','Like a Facebook post, share it, and leave a positive comment.','social','📘',150,'2 min','["Visit the Facebook post link","Click Like","Share to your timeline","Leave a genuine comment"]',4),
  ('task_005','Rate Mobile App on Play Store','Download a free app and rate it 5 stars with a short review.','app','⭐',350,'4 min','["Download the free app","Use the app for 1 minute","Rate 5 stars on Play Store","Write a short genuine review"]',5),
  ('task_006','Join Telegram Channel','Join a Telegram channel and stay for at least 30 days.','social','📢',300,'1 min','["Click the Telegram link","Join the channel","Do not leave within 30 days","Reward credited immediately"]',6),
  ('task_007','Write Product Review','Write an honest 50-word review on Jumia or Konga.','review','✍️',400,'6 min','["Visit the product page","Write honest review (50+ words)","Submit the review","Share a screenshot"]',7),
  ('task_008','Stream Song on Spotify','Play a song on Spotify for at least 30 seconds.','video','🎵',120,'1 min','["Open Spotify","Search for the specified song","Play for at least 30 seconds","Confirm completion here"]',8),
  ('task_009','Sign Up on Platform','Create a free account on a partner platform.','app','📲',600,'5 min','["Visit the signup link","Register with real details","Verify your email","Reward credited within 10 minutes"]',9),
  ('task_010','Political Opinion Poll','Answer 5 questions about Nigerian governance.','survey','🗳️',220,'3 min','["Open the poll link","Answer all 5 questions","Submit responses","Reward credited in 60 seconds"]',10),
  ('task_011','Retweet & Follow on Twitter/X','Follow a brand account and retweet their pinned post.','social','🐦',200,'2 min','["Open the Twitter/X profile","Click Follow","Retweet the pinned post","Do not unfollow within 14 days"]',11),
  ('task_012','Google Maps Business Review','Leave a 5-star Google Maps review with a genuine comment.','review','🏪',380,'4 min','["Search for the business on Google Maps","Click Write a Review","Give 5 stars and write 15+ words","Submit and screenshot"]',12)
ON CONFLICT (id) DO NOTHING;

-- ─── 9. CREATE FIRST ADMIN ───────────────────────────────────
-- After registering via the website, run this to promote yourself to admin.
-- Replace YOUR-EMAIL@example.com with your actual registered email.
--
-- UPDATE public.profiles
-- SET role = 'admin'
-- WHERE email = 'YOUR-EMAIL@example.com';

-- ─── DONE ─────────────────────────────────────────────────────
-- All tables created. You can now use Grindpoint fully.
-- Visit your site and register your first admin account.
