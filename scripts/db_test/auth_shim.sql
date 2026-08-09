-- ============================================================
-- Auth shim for testing migrations outside Supabase.
-- Minimal stand-in for Supabase Auth (schema `auth`) so that
-- migration SQL referencing auth.uid() / auth.users / role
-- `authenticated` can run on a plain PostgreSQL instance.
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY,
  email TEXT,
  raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- auth.uid() — current request user id.
-- In real Supabase the JWT sub claim lands in the `request.jwt.claim.sub`
-- GUC, visible inside SECURITY DEFINER functions because the caller is
-- authenticated. Here we store it on the session too so it survives
-- SECURITY DEFINER execution contexts.
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid,
    NULLIF(current_setting('app.current_user_id', true), '')::uuid
  )
$$;

-- Convenience helpers for tests: set current user.
-- `is_local=false` keeps the value for the whole session (psql runs each
-- statement in its own transaction, so local=true would reset it).
CREATE OR REPLACE FUNCTION auth.set_current_user(p_uid uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_uid::text, false);
  PERFORM set_config('app.current_user_id', p_uid::text, false);
END;
$$;

-- Alias expected by some policies.
CREATE OR REPLACE FUNCTION auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT current_setting('request.jwt.claim.role', true)
$$;

-- ============================================================
-- Storage shim: minimal stand-in for Supabase Storage so that
-- the avatars migration (buckets/objects/foldername) can run.
-- ============================================================
CREATE SCHEMA IF NOT EXISTS storage;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  public BOOLEAN DEFAULT false,
  file_size_limit BIGINT DEFAULT NULL,
  allowed_mime_types TEXT[] DEFAULT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id TEXT REFERENCES storage.buckets(id),
  name TEXT NOT NULL,
  owner UUID,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION storage.foldername(name TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  result TEXT[];
BEGIN
  result := string_to_array(name, '/');
  RETURN result[1:greatest(array_length(result, 1) - 1, 0)];
END;
$$;
