-- Migration: Create deposit_requests table
-- Description: New table to track deposit requests with admin verification workflow
-- Date: 2026-06-20

-- Create deposit_requests table
CREATE TABLE IF NOT EXISTS public.deposit_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  amount DECIMAL(18, 2) NOT NULL,
  currency TEXT DEFAULT 'NGN',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected','cancelled')),
  payment_proof_url TEXT,
  payment_reference TEXT,
  payment_date TIMESTAMPTZ,
  bank_name TEXT,
  sender_account_name TEXT,
  sender_account_number TEXT,
  admin_notes TEXT,
  verified_by UUID REFERENCES public.profiles(id),
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_deposit_requests_profile ON public.deposit_requests(profile_id);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_status ON public.deposit_requests(status);
CREATE INDEX IF NOT EXISTS idx_deposit_requests_created ON public.deposit_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.deposit_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS deposit_requests_self_select ON public.deposit_requests;
DROP POLICY IF EXISTS deposit_requests_self_modify ON public.deposit_requests;
CREATE POLICY deposit_requests_self_select ON public.deposit_requests FOR SELECT USING (profile_id = auth.uid() OR public.is_staff());
CREATE POLICY deposit_requests_self_modify ON public.deposit_requests FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- Add auto-update trigger
DROP TRIGGER IF EXISTS set_updated_at ON public.deposit_requests;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.deposit_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Add is_staff() helper function if not exists
-- Fixed: Added 'super_admin' role (with underscore) which is used in the database
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin', 'superadmin', 'staff', 'operator', 'viewer')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;
