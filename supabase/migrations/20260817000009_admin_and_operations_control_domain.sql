-- =============================================================================
-- Cerelo V1 — Admin & Operations Control Domain Migration
-- Version: 20260817000009
-- Description: Operations dashboard read models, controlled shipment corrections,
--              personnel RBAC/suspension, payment adjustments, incident resolution,
--              business configuration toggles, and immutable audit queries.
-- =============================================================================

-- =============================================================================
-- SECTION 1: AUDIT LOGS & INCIDENTS TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_user_id  UUID NOT NULL REFERENCES auth.users(id),
  actor_email    TEXT NOT NULL,
  action         TEXT NOT NULL,
  aggregate_type TEXT NOT NULL,
  aggregate_id   UUID,
  reason         TEXT NOT NULL,
  before_state   JSONB,
  after_state    JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_created_at ON public.admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_aggregate ON public.admin_audit_logs(aggregate_type, aggregate_id);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs"
  ON public.admin_audit_logs FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid()));

-- Operational Incidents Table
CREATE TABLE IF NOT EXISTS public.incidents (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id           UUID REFERENCES public.shipments(id) ON DELETE SET NULL,
  parcel_id             UUID REFERENCES public.parcels(id) ON DELETE SET NULL,
  batch_id              UUID REFERENCES public.batches(id) ON DELETE SET NULL,
  raised_by_personnel_id UUID REFERENCES public.personnel(id),
  category              TEXT NOT NULL,  -- maps to OperationalIncidentCategory codes
  description           TEXT NOT NULL,
  status                TEXT NOT NULL DEFAULT 'OPEN'
                          CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'CLOSED')),
  severity              TEXT NOT NULL DEFAULT 'MEDIUM'
                          CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  resolution_notes      TEXT,
  resolved_by_admin_id  UUID REFERENCES public.admin_users(id),
  resolved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.incidents IS
  'Operational incidents raised during physical logistics operations. Resolved only by admins.';

CREATE TRIGGER trg_incidents_updated_at
  BEFORE UPDATE ON public.incidents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS idx_incidents_status
  ON public.incidents(status) WHERE status IN ('OPEN', 'INVESTIGATING');

CREATE INDEX IF NOT EXISTS idx_incidents_shipment
  ON public.incidents(shipment_id) WHERE shipment_id IS NOT NULL;

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

-- Personnel can read incidents related to operations
CREATE POLICY "incidents: personnel read open"
  ON public.incidents FOR SELECT
  TO authenticated
  USING ((auth.jwt() ->> 'role') IN ('personnel', 'admin'));

-- Only admins can update (resolve) incidents
CREATE POLICY "incidents: admin update"
  ON public.incidents FOR UPDATE
  TO authenticated
  USING ((auth.jwt() ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() ->> 'role') = 'admin');

-- Personnel can create (raise) incidents
CREATE POLICY "incidents: personnel insert"
  ON public.incidents FOR INSERT
  TO authenticated
  WITH CHECK ((auth.jwt() ->> 'role') IN ('personnel', 'admin'));

-- =============================================================================
-- SECTION 2: ADMIN OPERATIONAL METRICS & OVERVIEW RPCS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_admin_overview_metrics()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'requests_awaiting_pickup', (SELECT COUNT(*) FROM public.shipments WHERE current_status = 'REQUESTED'),
    'parcels_in_custody', (SELECT COUNT(*) FROM public.parcels WHERE current_parcel_state = 'IN_CERELO_CUSTODY'),
    'origin_hub_staged', (SELECT COUNT(*) FROM public.parcels WHERE current_parcel_state = 'ORIGIN_HUB_STAGED'),
    'draft_batches', (SELECT COUNT(*) FROM public.batches WHERE current_batch_state = 'DRAFT'),
    'confirmed_batches', (SELECT COUNT(*) FROM public.batches WHERE current_batch_state = 'CONFIRMED'),
    'in_transit_batches', (SELECT COUNT(*) FROM public.batches WHERE current_batch_state = 'ONBOARDED'),
    'destination_received_batches', (SELECT COUNT(*) FROM public.batches WHERE current_batch_state = 'DESTINATION_RECEIVED'),
    'ready_for_delivery', (SELECT COUNT(*) FROM public.shipments WHERE current_status = 'ARRIVED_DESTINATION'),
    'out_for_delivery', (SELECT COUNT(*) FROM public.shipments WHERE current_status = 'OUT_FOR_DELIVERY'),
    'delivered_today', (SELECT COUNT(*) FROM public.shipments WHERE current_status = 'DELIVERED' AND delivered_at >= CURRENT_DATE),
    'open_incidents', (SELECT COUNT(*) FROM public.incidents WHERE status = 'OPEN'),
    'total_collected_today_kobo', COALESCE((SELECT SUM(amount_collected) FROM public.payment_collections WHERE created_at >= CURRENT_DATE), 0),
    'kano_to_katsina_active_shipments', (SELECT COUNT(*) FROM public.shipments WHERE origin_city = 'Kano' AND destination_city = 'Katsina' AND current_status NOT IN ('DELIVERED', 'CANCELLED')),
    'katsina_to_kano_active_shipments', (SELECT COUNT(*) FROM public.shipments WHERE origin_city = 'Katsina' AND destination_city = 'Kano' AND current_status NOT IN ('DELIVERED', 'CANCELLED'))
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 3: CONTROLLED SHIPMENT CORRECTIONS & AUDIT RPCS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_correct_receiver_details(
  p_shipment_id UUID,
  p_new_phone TEXT,
  p_new_address TEXT,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_shipment RECORD;
  v_before JSONB;
  v_after JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RAISE EXCEPTION 'A valid operational reason is required for administrative corrections.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status = 'DELIVERED' THEN
    RAISE EXCEPTION 'Delivered shipments cannot have receiver details altered.' USING ERRCODE = '23514';
  END IF;

  v_before := jsonb_build_object(
    'receiver_phone', v_shipment.receiver_phone_snapshot,
    'receiver_address', v_shipment.receiver_delivery_address_snapshot
  );

  UPDATE public.shipments
  SET receiver_phone_snapshot = COALESCE(TRIM(p_new_phone), receiver_phone_snapshot),
      receiver_delivery_address_snapshot = COALESCE(TRIM(p_new_address), receiver_delivery_address_snapshot)
  WHERE id = p_shipment_id;

  v_after := jsonb_build_object(
    'receiver_phone', COALESCE(TRIM(p_new_phone), v_shipment.receiver_phone_snapshot),
    'receiver_address', COALESCE(TRIM(p_new_address), v_shipment.receiver_delivery_address_snapshot)
  );

  -- Record Immutable Audit Log
  INSERT INTO public.admin_audit_logs (
    actor_user_id,
    actor_email,
    action,
    aggregate_type,
    aggregate_id,
    reason,
    before_state,
    after_state
  )
  VALUES (
    v_user_id,
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'CORRECT_RECEIVER_DETAILS',
    'SHIPMENT',
    p_shipment_id,
    TRIM(p_reason),
    v_before,
    v_after
  );

  INSERT INTO public.operational_events (
    aggregate_type,
    aggregate_id,
    event_type,
    actor_id,
    actor_role,
    location_hub_id,
    payload
  )
  VALUES (
    'SHIPMENT',
    p_shipment_id,
    'ADMIN_RECEIVER_DETAILS_CORRECTED',
    v_admin.id,
    'ADMIN',
    v_shipment.origin_hub_id,
    jsonb_build_object('reason', p_reason, 'before', v_before, 'after', v_after)
  );

  RETURN jsonb_build_object('success', true, 'shipment_id', p_shipment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: PERSONNEL STATUS & SCOPE MANAGEMENT
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_set_personnel_status(
  p_personnel_id UUID,
  p_is_active BOOLEAN,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_personnel RECORD;
  v_before JSONB;
  v_after JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason required for personnel status change.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_personnel FROM public.personnel WHERE id = p_personnel_id;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Personnel not found.' USING ERRCODE = 'P0002';
  END IF;

  v_before := jsonb_build_object('is_active', v_personnel.is_active);

  UPDATE public.personnel
  SET is_active = p_is_active
  WHERE id = p_personnel_id;

  v_after := jsonb_build_object('is_active', p_is_active);

  INSERT INTO public.admin_audit_logs (
    actor_user_id,
    actor_email,
    action,
    aggregate_type,
    aggregate_id,
    reason,
    before_state,
    after_state
  )
  VALUES (
    v_user_id,
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'SET_PERSONNEL_STATUS',
    'PERSONNEL',
    p_personnel_id,
    TRIM(p_reason),
    v_before,
    v_after
  );

  RETURN jsonb_build_object('success', true, 'personnel_id', p_personnel_id, 'is_active', p_is_active);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 5: INCIDENT RESOLUTION RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_resolve_incident(
  p_incident_id UUID,
  p_resolution_notes TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_incident RECORD;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_incident FROM public.incidents WHERE id = p_incident_id;
  IF v_incident IS NULL THEN
    RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.incidents
  SET status = 'RESOLVED',
      resolved_at = NOW(),
      resolved_by_admin_id = v_admin.id,
      resolution_notes = TRIM(p_resolution_notes)
  WHERE id = p_incident_id;

  INSERT INTO public.admin_audit_logs (
    actor_user_id,
    actor_email,
    action,
    aggregate_type,
    aggregate_id,
    reason,
    before_state,
    after_state
  )
  VALUES (
    v_user_id,
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'RESOLVE_INCIDENT',
    'INCIDENT',
    p_incident_id,
    TRIM(p_resolution_notes),
    jsonb_build_object('status', 'OPEN'),
    jsonb_build_object('status', 'RESOLVED')
  );

  RETURN jsonb_build_object('success', true, 'incident_id', p_incident_id, 'status', 'RESOLVED');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 6: CONFIGURATION TOGGLES & PRICING
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_toggle_corridor_active(
  p_corridor_id UUID,
  p_is_active BOOLEAN,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_corridor RECORD;
  v_before JSONB;
  v_after JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_corridor FROM public.corridors WHERE id = p_corridor_id;
  IF v_corridor IS NULL THEN
    RAISE EXCEPTION 'Corridor not found.' USING ERRCODE = 'P0002';
  END IF;

  v_before := jsonb_build_object('is_active', v_corridor.is_active);

  UPDATE public.corridors
  SET is_active = p_is_active
  WHERE id = p_corridor_id;

  v_after := jsonb_build_object('is_active', p_is_active);

  INSERT INTO public.admin_audit_logs (
    actor_user_id,
    actor_email,
    action,
    aggregate_type,
    aggregate_id,
    reason,
    before_state,
    after_state
  )
  VALUES (
    v_user_id,
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'TOGGLE_CORRIDOR_ACTIVE',
    'CORRIDOR',
    p_corridor_id,
    TRIM(p_reason),
    v_before,
    v_after
  );

  RETURN jsonb_build_object('success', true, 'corridor_id', p_corridor_id, 'is_active', p_is_active);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.admin_update_pricing_rule(
  p_pricing_rule_id UUID,
  p_base_price_kobo INT,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_rule RECORD;
  v_before JSONB;
  v_after JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  IF p_base_price_kobo <= 0 THEN
    RAISE EXCEPTION 'Price must be positive.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_rule FROM public.pricing_rules WHERE id = p_pricing_rule_id;
  IF v_rule IS NULL THEN
    RAISE EXCEPTION 'Pricing rule not found.' USING ERRCODE = 'P0002';
  END IF;

  v_before := jsonb_build_object('base_price_amount', v_rule.base_price_amount);

  UPDATE public.pricing_rules
  SET base_price_amount = p_base_price_kobo
  WHERE id = p_pricing_rule_id;

  v_after := jsonb_build_object('base_price_amount', p_base_price_kobo);

  INSERT INTO public.admin_audit_logs (
    actor_user_id,
    actor_email,
    action,
    aggregate_type,
    aggregate_id,
    reason,
    before_state,
    after_state
  )
  VALUES (
    v_user_id,
    (SELECT email FROM auth.users WHERE id = v_user_id),
    'UPDATE_PRICING_RULE',
    'PRICING_RULE',
    p_pricing_rule_id,
    TRIM(p_reason),
    v_before,
    v_after
  );

  RETURN jsonb_build_object('success', true, 'pricing_rule_id', p_pricing_rule_id, 'base_price_amount', p_base_price_kobo);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grants
GRANT EXECUTE ON FUNCTION public.get_admin_overview_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_correct_receiver_details(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_personnel_status(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_incident(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_corridor_active(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_pricing_rule(UUID, INT, TEXT) TO authenticated;
