-- =============================================================================
-- Cerelo V1 — Bootstrap Migration
-- Version: 20260817000001
-- Description: Identity & account tables, RLS foundation, configuration seed.
-- =============================================================================
-- This migration establishes the identity/account foundation only.
-- Full logistics schema (shipments, parcels, batches, payments, events)
-- is implemented in subsequent feature migration files.
--
-- SECURITY RULES EMBEDDED IN THIS MIGRATION:
--   ✓ RLS enabled on ALL tables (default-deny)
--   ✓ Explicit policies grant only known access paths
--   ✓ Role derived from app_metadata (server-set), never user_metadata
--   ✓ Customers cannot self-create personnel or admin records
--   ✓ FCM tokens are private — no cross-user visibility
-- =============================================================================

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;

-- Function alias for uuid_generate_v4() using core PostgreSQL gen_random_uuid()
CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
RETURNS UUID AS $$
  SELECT gen_random_uuid();
$$ LANGUAGE sql VOLATILE;

-- =============================================================================
-- SECTION 1: CUSTOMER PROFILES
-- Mirrors auth.users 1-to-1. Auto-created via trigger on customer signup.
-- =============================================================================

CREATE TABLE public.customers (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id       UUID GENERATED ALWAYS AS (id) STORED,
  full_name     TEXT NOT NULL
                  CHECK (char_length(full_name) >= 2 AND char_length(full_name) <= 100),
  phone_number  TEXT UNIQUE NOT NULL,  -- E.164: +2348012345678
  account_type  TEXT NOT NULL DEFAULT 'INDIVIDUAL'
                  CHECK (account_type IN ('INDIVIDUAL', 'BUSINESS')),
  business_name TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.customers IS 'Cerelo customer profiles. 1-to-1 with auth.users.';
COMMENT ON COLUMN public.customers.phone_number IS
  'Canonical E.164 phone. Used for receiver-linking and SMS delivery.';

-- =============================================================================
-- SECTION 2: PERSONNEL PROFILES
-- Internal field staff. Created by Admin — NOT self-registerable.
-- =============================================================================

CREATE TABLE public.personnel (
  id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id             UUID GENERATED ALWAYS AS (id) STORED,
  full_name           TEXT NOT NULL,
  phone_number        TEXT UNIQUE NOT NULL,
  employee_reference  TEXT UNIQUE,
  operating_hub_id    UUID,            -- FK added once operating_hubs table exists
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.personnel IS
  'Cerelo field staff profiles. Cannot be self-created by customers.';

-- =============================================================================
-- SECTION 3: ADMIN USERS
-- Internal admin/operations staff. Created by Super Admin only.
-- =============================================================================

CREATE TABLE public.admin_users (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  user_id    UUID GENERATED ALWAYS AS (id) STORED,
  full_name  TEXT NOT NULL,
  admin_role TEXT NOT NULL DEFAULT 'SUPPORT'
               CHECK (admin_role IN ('SUPER_ADMIN', 'OPS_MANAGER', 'SUPPORT')),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.admin_users IS
  'Cerelo admin/operations profiles. Cannot be self-created.';

-- Backward-compatible admins view for legacy queries expecting public.admins
CREATE OR REPLACE VIEW public.admins AS
  SELECT
    id,
    id          AS user_id,
    full_name,
    admin_role,
    is_active,
    created_at,
    updated_at
  FROM public.admin_users;

GRANT SELECT ON public.admins TO authenticated;

-- =============================================================================
-- SECTION 4: USER DEVICES — Push Notification Tokens
-- Per-device FCM tokens. A user may have multiple devices.
-- =============================================================================

CREATE TABLE public.user_devices (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token  TEXT NOT NULL UNIQUE,
  device_os  TEXT NOT NULL CHECK (device_os IN ('ANDROID', 'IOS', 'WEB')),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_devices IS
  'FCM push tokens per device. Never expose to other users.';

-- =============================================================================
-- SECTION 5: UPDATED_AT TRIGGER FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
  BEFORE UPDATE ON public.customers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_personnel_updated_at
  BEFORE UPDATE ON public.personnel
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_admin_users_updated_at
  BEFORE UPDATE ON public.admin_users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_user_devices_updated_at
  BEFORE UPDATE ON public.user_devices
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- SECTION 6: CUSTOMER AUTO-CREATE TRIGGER
-- Creates customer row when a new auth user signs up with role = customer.
-- Personnel and admin accounts are created manually by admin RPCs.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_customer_signup()
RETURNS TRIGGER AS $$
BEGIN
  -- Only auto-create for customer role (default when role is unset)
  IF (NEW.raw_app_meta_data->>'role' IS NULL OR
      NEW.raw_app_meta_data->>'role' = 'customer') THEN
    INSERT INTO public.customers (id, full_name, phone_number, account_type)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'full_name', 'New Customer'),
      COALESCE(NEW.phone, ''),
      COALESCE(NEW.raw_user_meta_data->>'account_type', 'INDIVIDUAL')
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_customer_signup();

-- =============================================================================
-- SECTION 7: ROW LEVEL SECURITY (RLS)
-- Default-DENY. Explicit policies grant only known access paths.
-- SECURITY: RLS MUST remain enabled on all tables. Never disable.
-- =============================================================================

ALTER TABLE public.customers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personnel   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- ─── customers RLS ──────────────────────────────────────────────────────────

-- Customers read and update only their own profile row.
CREATE POLICY "customers: select own profile"
  ON public.customers FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "customers: update own profile"
  ON public.customers FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Personnel can read customer names/phones for active operational tasks.
-- Fine-grained scoping (only assigned parcels) is enforced in Edge Functions.
CREATE POLICY "personnel: read customers for operations"
  ON public.customers FOR SELECT
  USING ((auth.jwt() ->> 'role') = 'personnel');

-- Admin: full read access.
CREATE POLICY "admin: full customer read access"
  ON public.customers FOR SELECT
  USING ((auth.jwt() ->> 'role') = 'admin');

-- ─── personnel RLS ──────────────────────────────────────────────────────────

CREATE POLICY "personnel: select own profile"
  ON public.personnel FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "admin: full personnel read access"
  ON public.personnel FOR SELECT
  USING ((auth.jwt() ->> 'role') = 'admin');

-- ─── admin_users RLS ────────────────────────────────────────────────────────

CREATE POLICY "admin_users: select own record"
  ON public.admin_users FOR SELECT
  USING (auth.uid() = id);

-- Super admin reads all admin user records.
CREATE POLICY "super_admin: full admin_users read"
  ON public.admin_users FOR SELECT
  USING (
    (auth.jwt() ->> 'role') = 'admin' AND
    (auth.jwt() -> 'app_metadata' ->> 'admin_role') = 'SUPER_ADMIN'
  );

-- ─── user_devices RLS ───────────────────────────────────────────────────────

-- Users manage only their own FCM device tokens.
-- SECURITY: No cross-user token visibility.
CREATE POLICY "users: manage own devices"
  ON public.user_devices FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- SECTION 8: INDEXES
-- =============================================================================

CREATE INDEX idx_customers_phone        ON public.customers(phone_number);
CREATE INDEX idx_customers_active       ON public.customers(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_personnel_active       ON public.personnel(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_personnel_hub          ON public.personnel(operating_hub_id) WHERE operating_hub_id IS NOT NULL;
CREATE UNIQUE INDEX idx_personnel_user_id ON public.personnel(user_id);
CREATE UNIQUE INDEX idx_admin_users_user_id ON public.admin_users(user_id);
CREATE INDEX idx_user_devices_user_id   ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_token     ON public.user_devices(fcm_token);

-- =============================================================================
-- SECTION 9: ROLE GRANTS & DEFAULT PRIVILEGES
-- Ensures PostgREST roles (anon, authenticated, service_role) have table access.
-- Actual data security is enforced at the row level by Row Level Security (RLS).
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

