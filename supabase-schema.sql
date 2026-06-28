-- ===================================================
-- GTA VI Hub - Database Schema
-- Run this in Supabase SQL Editor
-- ===================================================

-- Profiles table (auto-created on signup via trigger)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE,
  avatar_url TEXT,
  display_name TEXT,
  bio TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Membership table
CREATE TABLE public.memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE NOT NULL,
  tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'premium', 'elite')),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Forum categories
CREATE TABLE public.forum_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  min_tier TEXT NOT NULL DEFAULT 'free' CHECK (min_tier IN ('free', 'premium', 'elite')),
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Forum threads
CREATE TABLE public.forum_threads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category_id UUID REFERENCES public.forum_categories(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  pinned BOOLEAN DEFAULT false,
  locked BOOLEAN DEFAULT false,
  post_count INT DEFAULT 0,
  view_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Forum posts
CREATE TABLE public.forum_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  thread_id UUID REFERENCES public.forum_threads(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  is_first_post BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Guides / gated content
CREATE TABLE public.guides (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('money', 'cars', 'locations', 'maps', 'secrets', 'analysis')),
  min_tier TEXT NOT NULL DEFAULT 'free' CHECK (min_tier IN ('free', 'premium', 'elite')),
  image_url TEXT,
  author_id UUID REFERENCES public.profiles(id),
  published BOOLEAN DEFAULT false,
  view_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Map pins (community contributed)
CREATE TABLE public.map_pins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  lat FLOAT NOT NULL,
  lng FLOAT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL DEFAULT 'community',
  image_url TEXT,
  min_tier TEXT NOT NULL DEFAULT 'free' CHECK (min_tier IN ('free', 'premium', 'elite')),
  approved BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ===================================================
-- ROW LEVEL SECURITY
-- ===================================================

-- Profiles: users can read all, update own
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Memberships: users can read own
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own membership" ON public.memberships FOR SELECT USING (auth.uid() = user_id);

-- Forum: Free tier can read all public, premium/elite see their own?
ALTER TABLE public.forum_categories ENABLE ROW LEVEL SECURITY;
-- Simplified: let the app handle permission logic via API

-- ===================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ===================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, username, display_name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User')
  );

  INSERT INTO public.memberships (user_id, tier)
  VALUES (NEW.id, 'free');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ===================================================
-- Early Access Launch Program
-- ===================================================
CREATE TABLE public.launch_registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  claimed_premium BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Function to count remaining spots
CREATE OR REPLACE FUNCTION remaining_launch_spots()
RETURNS INT AS $$
BEGIN
  RETURN GREATEST(0, 500 - (SELECT COUNT(*) FROM public.launch_registrations));
END;
$$ LANGUAGE plpgsql;

-- ===================================================
-- SEED DATA: Forum Categories
-- ===================================================
INSERT INTO public.forum_categories (name, slug, description, min_tier, sort_order) VALUES
  ('General Discussion', 'general', 'Chat about GTA VI, gaming, and anything else', 'free', 1),
  ('News & Rumors', 'news-rumors', 'Discuss the latest GTA VI news, leaks, and rumors', 'free', 2),
  ('Maps & Locations', 'maps-locations', 'Share and find locations, Easter eggs, and secrets', 'free', 3),
  ('Money Making Guides', 'money-guides', 'Best methods to make money in GTA VI', 'premium', 4),
  ('Car & Vehicle Hub', 'cars-vehicles', 'Vehicle locations, stats, and customization', 'premium', 5),
  ('Elite Lounge', 'elite-lounge', 'Exclusive early access content and elite discussion', 'elite', 6),
  ('Showcase & Creations', 'showcase', 'Share your screenshots, clips, and fan creations', 'free', 7);

-- ===================================================
-- SEED DATA: Sample Guides
-- ===================================================
INSERT INTO public.guides (title, slug, description, content, category, min_tier, published) VALUES
  ('Top 10 Money Making Methods in Leonida', 'top-10-money-methods', 'The fastest ways to stack cash in GTA VI from day one', 'Detailed guide content here...', 'money', 'premium', true),
  ('All Hidden Vehicle Locations', 'hidden-vehicle-locations', 'Every rare car, bike, and boat spawn location mapped out', 'Detailed guide content here...', 'cars', 'premium', true),
  ('Secret Loot Map: Underground Caches', 'secret-loot-map', 'Hidden weapon caches, money stashes, and rare items', 'Detailed guide content here...', 'locations', 'elite', true);

-- ===================================================
-- FUNCTIONS
-- ===================================================

-- Increment thread view count
CREATE OR REPLACE FUNCTION increment_thread_views(thread_slug TEXT)
RETURNS void AS $$
BEGIN
  UPDATE forum_threads SET view_count = view_count + 1 WHERE slug = thread_slug;
END;
$$ LANGUAGE plpgsql;

-- Increment guide view count
CREATE OR REPLACE FUNCTION increment_guide_views(guide_slug TEXT)
RETURNS void AS $$
BEGIN
  UPDATE guides SET view_count = view_count + 1 WHERE slug = guide_slug;
END;
$$ LANGUAGE plpgsql;
