-- Users table (extends Supabase Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  user_id TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  name TEXT,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'admin', 'superadmin')),
  is_active BOOLEAN DEFAULT true,
  is_flagged BOOLEAN DEFAULT false,
  flagged_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- KYC table
CREATE TABLE IF NOT EXISTS public.kyc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  verified BOOLEAN DEFAULT false,
  verified_at TIMESTAMPTZ,
  national_id TEXT,
  address TEXT,
  date_of_birth DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Savings table
CREATE TABLE IF NOT EXISTS public.savings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_saved DECIMAL(15, 2) DEFAULT 0,
  monthly_savings DECIMAL(15, 2) DEFAULT 0,
  first_savings_date TIMESTAMPTZ,
  consecutive_months INTEGER DEFAULT 0,
  last_savings_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Referrals table
CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  my_referral_code TEXT UNIQUE,
  referred_by_id UUID REFERENCES public.profiles(id),
  referred_by_code TEXT,
  referral_count INTEGER DEFAULT 0,
  confirmed_referral_count INTEGER DEFAULT 0,
  current_tier_bonus DECIMAL(5, 2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Profiles policies
-- ============================================================
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile." ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile." ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ============================================================
-- KYC policies
-- ============================================================
CREATE POLICY "Users can view own KYC." ON public.kyc
  FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Users can insert own KYC." ON public.kyc
  FOR INSERT WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can update own KYC." ON public.kyc
  FOR UPDATE USING (profile_id = auth.uid());

-- ============================================================
-- Savings policies
-- ============================================================
CREATE POLICY "Users can view own savings." ON public.savings
  FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Users can insert own savings." ON public.savings
  FOR INSERT WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can update own savings." ON public.savings
  FOR UPDATE USING (profile_id = auth.uid());

-- ============================================================
-- Referrals policies
-- ============================================================
CREATE POLICY "Users can view own referrals." ON public.referrals
  FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Users can insert own referrals." ON public.referrals
  FOR INSERT WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can update own referrals." ON public.referrals
  FOR UPDATE USING (profile_id = auth.uid());

-- ============================================================
-- Trigger: auto-create profile row when a new auth user signs up
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, user_id, email, name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'userId', 'USR-' || substr(NEW.id::text, 1, 8)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'member')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
