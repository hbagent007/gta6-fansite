-- ============================================================
-- GTA6 Fansite — Membership & Launch Special SQL Setup
-- Apply this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- 1. Profiles extension table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Launch registrations (tracks signups for first-500 special)
CREATE TABLE IF NOT EXISTS public.launch_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  claimed_premium BOOLEAN DEFAULT false,
  registered_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

-- 3. Membership records
CREATE TABLE IF NOT EXISTS public.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium', 'elite')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired')),
  started_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ
);

-- ============================================================
-- Row-Level Security
-- ============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.launch_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update their own
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can upsert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Launch registrations: anyone can read count, users insert own
CREATE POLICY "Anyone can read launch count"
  ON public.launch_registrations FOR SELECT
  USING (true);

CREATE POLICY "Users can register themselves"
  ON public.launch_registrations FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Memberships: users read own, service role manages all
CREATE POLICY "Users can read own membership"
  ON public.memberships FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role manages memberships"
  ON public.memberships FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================================
-- Trigger: Auto-setup new users
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  reg_count INTEGER;
BEGIN
  -- Create profile
  INSERT INTO public.profiles (id, username)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)));

  -- Check remaining launch spots (first 500 get Premium)
  SELECT COUNT(*) INTO reg_count FROM public.launch_registrations;

  -- Register for launch special
  INSERT INTO public.launch_registrations (user_id, email, claimed_premium)
  VALUES (NEW.id, NEW.email, reg_count < 500);

  -- Create membership (Premium if within first 500, Free otherwise)
  IF reg_count < 500 THEN
    INSERT INTO public.memberships (user_id, tier, status)
    VALUES (NEW.id, 'premium', 'active');
  ELSE
    INSERT INTO public.memberships (user_id, tier, status)
    VALUES (NEW.id, 'free', 'active');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- Indexes for performance
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_launch_registrations_user_id ON public.launch_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user_id ON public.memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_tier ON public.memberships(tier);
