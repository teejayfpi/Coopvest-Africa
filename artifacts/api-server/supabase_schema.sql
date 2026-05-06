-- Coopvest Africa — Supabase schema
-- Run this in the Supabase SQL Editor: https://app.supabase.com/project/_/sql

-- Users table
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  password_hash text not null,
  name text not null,
  phone text,
  kyc_status text not null default 'pending',
  membership_status text not null default 'active',
  referral_code text unique,
  referred_by uuid references public.users(id),
  email_verified boolean not null default false,
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- OTP codes table
create table if not exists public.otp_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  code text not null,
  type text not null,  -- 'email_verification' | 'password_reset'
  expires_at timestamptz not null,
  used boolean not null default false,
  created_at timestamptz not null default now()
);

-- Refresh tokens table
create table if not exists public.refresh_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  token_hash text not null,
  expires_at timestamptz not null,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);

-- KYC submissions table
create table if not exists public.kyc_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  data jsonb not null,
  submitted_at timestamptz not null default now()
);

-- Row Level Security (allow service_role to bypass)
alter table public.users enable row level security;
alter table public.otp_codes enable row level security;
alter table public.refresh_tokens enable row level security;
alter table public.kyc_submissions enable row level security;

-- Service role bypass policies
create policy "service_role full access users" on public.users for all using (true);
create policy "service_role full access otp_codes" on public.otp_codes for all using (true);
create policy "service_role full access refresh_tokens" on public.refresh_tokens for all using (true);
create policy "service_role full access kyc_submissions" on public.kyc_submissions for all using (true);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.users
  for each row execute function update_updated_at();
