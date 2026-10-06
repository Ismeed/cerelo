-- =============================================================================
-- Cerelo V1 — Admin Batch and Middle-Mile Read Access Policies
-- Version: 20260831000028
-- Description:
--   Grants authenticated and active Admin users SELECT permissions on
--   batches, transit_runs, transport_partners, and batch_memberships tables
--   using public.is_active_admin().
-- =============================================================================

-- 1. batches table admin read policy
DROP POLICY IF EXISTS "batches: admin full read" ON public.batches;
CREATE POLICY "batches: admin full read"
  ON public.batches FOR SELECT
  TO authenticated
  USING (public.is_active_admin());

-- 2. transit_runs table admin read policy
DROP POLICY IF EXISTS "transit_runs: admin full read" ON public.transit_runs;
CREATE POLICY "transit_runs: admin full read"
  ON public.transit_runs FOR SELECT
  TO authenticated
  USING (public.is_active_admin());

-- 3. transport_partners table admin read policy
DROP POLICY IF EXISTS "transport_partners: admin full read" ON public.transport_partners;
CREATE POLICY "transport_partners: admin full read"
  ON public.transport_partners FOR SELECT
  TO authenticated
  USING (public.is_active_admin());

-- 4. batch_memberships table admin read policy
DROP POLICY IF EXISTS "batch_memberships: admin full read" ON public.batch_memberships;
CREATE POLICY "batch_memberships: admin full read"
  ON public.batch_memberships FOR SELECT
  TO authenticated
  USING (public.is_active_admin());
