-- Migration: Add firebase_uid column to profiles table
-- Run this against your Supabase database to support Firebase Auth migration.

-- Add firebase_uid column (TEXT, unique, nullable during migration)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS firebase_uid TEXT;

-- Create a unique index so two profiles can't share the same Firebase UID
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_firebase_uid
  ON public.profiles (firebase_uid)
  WHERE firebase_uid IS NOT NULL;

-- Create a fast lookup index used by the auth middleware on every request
CREATE INDEX IF NOT EXISTS idx_profiles_firebase_uid_lookup
  ON public.profiles (firebase_uid);
