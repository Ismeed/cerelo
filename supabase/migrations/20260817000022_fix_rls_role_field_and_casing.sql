-- =============================================================================
-- Cerelo V1 - RLS Role Field Fix and Personnel Role Casing Normalization
-- Version: 20260817000022
-- Description:
--   CRITICAL FIX: All previous RLS policies used (auth.jwt() ->> 'role') which
--   returns 'authenticated' (the Postgres role), NOT the custom Cerelo role.
--   The custom role is stored in app_metadata and exposed as:
--     (auth.jwt() -> 'app_metadata' ->> 'role')
--
--   This migration:
--   1. Replaces all broken auth.jwt()->>role checks across all affected tables
--      with the correct app_metadata-based helper functions.
--   2. Introduces cerelo_role() stable helper to centralize role extraction.
--   3. All fixes use the already-correct is_active_admin() and is_active_personnel()
--      helpers from migration 21, extending their use to all tables.
--
-- ROOT CAUSE:
--   auth.jwt() ->> 'role' = 'authenticated' (always, Postgres role)
--   auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'|'personnel'|'customer'
-- =============================================================================

-- =============================================================================
-- SECTION 1: STABLE ROLE EXTRACTION HELPER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.cerelo_role()
RETURNS TEXT AS $$
  SELECT LOWER(COALESCE(
    auth.jwt() -> 'app_metadata' ->> 'role',
    ''
  ));
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public;

GRANT EXECUTE ON FUNCTION public.cerelo_role() TO authenticated;

-- =============================================================================
-- SECTION 2: FIX public.customers POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "personnel: read customers for operations" ON public.customers;
DROP POLICY IF EXISTS "admin: full customer read access" ON public.customers;

CREATE POLICY "personnel: read customers for operations"
  ON public.customers FOR SELECT
  USING (public.is_active_personnel());

CREATE POLICY "admin: full customer read access"
  ON public.customers FOR SELECT
  USING (public.is_active_admin());

-- =============================================================================
-- SECTION 3: FIX public.personnel POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "admin: full personnel read access" ON public.personnel;

CREATE POLICY "admin: full personnel read access"
  ON public.personnel FOR SELECT
  USING (public.is_active_admin());

-- =============================================================================
-- SECTION 4: FIX public.admin_users POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "super_admin: full admin_users read" ON public.admin_users;

CREATE POLICY "super_admin: full admin_users read"
  ON public.admin_users FOR SELECT
  USING (
    public.is_active_admin() AND
    (auth.jwt() -> 'app_metadata' ->> 'admin_role') = 'SUPER_ADMIN'
  );

-- =============================================================================
-- SECTION 5: FIX public.shipments POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "shipments: personnel and admin read all" ON public.shipments;
DROP POLICY IF EXISTS "shipments: select for stakeholders" ON public.shipments;
DROP POLICY IF EXISTS "shipments: update for personnel or admin" ON public.shipments;

CREATE POLICY "shipments: personnel and admin read all"
  ON public.shipments FOR SELECT
  USING (
    public.is_active_admin()
    OR public.is_active_personnel()
    OR sender_customer_id = auth.uid()
    OR receiver_customer_id = auth.uid()
  );

-- =============================================================================
-- SECTION 6: FIX public.share_tokens POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "share_tokens: personnel and admin read" ON public.share_tokens;

CREATE POLICY "share_tokens: personnel and admin read"
  ON public.share_tokens FOR SELECT
  USING (
    created_by_customer_id = auth.uid()
    OR public.is_active_admin()
    OR public.is_active_personnel()
  );

-- =============================================================================
-- SECTION 7: FIX pickup domain POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "receiver_verifications: personnel read" ON public.receiver_verifications;
DROP POLICY IF EXISTS "parcel_size_corrections: personnel read" ON public.parcel_size_corrections;
DROP POLICY IF EXISTS "payment_collections: personnel read" ON public.payment_collections;
DROP POLICY IF EXISTS "pickup_exceptions: personnel read" ON public.pickup_exceptions;

CREATE POLICY "receiver_verifications: personnel admin read"
  ON public.receiver_verifications FOR SELECT
  USING (public.is_active_admin() OR public.is_active_personnel());

CREATE POLICY "parcel_size_corrections: personnel admin read"
  ON public.parcel_size_corrections FOR SELECT
  USING (public.is_active_admin() OR public.is_active_personnel());

CREATE POLICY "payment_collections: personnel admin read"
  ON public.payment_collections FOR SELECT
  USING (public.is_active_admin() OR public.is_active_personnel());

CREATE POLICY "pickup_exceptions: personnel admin read"
  ON public.pickup_exceptions FOR SELECT
  USING (public.is_active_admin() OR public.is_active_personnel());

-- =============================================================================
-- SECTION 8: FIX incidents POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "incidents: personnel read open" ON public.incidents;
DROP POLICY IF EXISTS "incidents: admin update" ON public.incidents;
DROP POLICY IF EXISTS "incidents: personnel insert" ON public.incidents;

CREATE POLICY "incidents: personnel read open"
  ON public.incidents FOR SELECT
  USING (public.is_active_admin() OR public.is_active_personnel());

CREATE POLICY "incidents: admin update"
  ON public.incidents FOR UPDATE
  USING (public.is_active_admin())
  WITH CHECK (public.is_active_admin());

CREATE POLICY "incidents: personnel insert"
  ON public.incidents FOR INSERT
  WITH CHECK (public.is_active_admin() OR public.is_active_personnel());

-- =============================================================================
-- SECTION 9: FIX admin_audit_logs POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.admin_audit_logs;

CREATE POLICY "admin_audit_logs: admin read"
  ON public.admin_audit_logs FOR SELECT
  USING (public.is_active_admin());
