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

-- Create policies
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile." ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile." ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
