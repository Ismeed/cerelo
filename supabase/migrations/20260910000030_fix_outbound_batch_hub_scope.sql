-- =============================================================================
-- Cerelo V1 — P1 Fix: Outbound Batch Domain Missing Operational-Scope (Hub) Checks
-- Version: 20260910000030
-- Description:
--   RUNTIME-VERIFIED DEFECT (Phase 3 autonomous staging audit, 2026-09-10):
--   The entire outbound/origin batch-management pipeline - create_batch,
--   add_parcel_to_batch, remove_parcel_from_draft_batch, confirm_batch,
--   set_batch_transport_arrangement, onboard_batch, and receive_parcel_at_
--   origin_hub - checked only "is this caller an active Personnel", never
--   "does this batch/parcel belong to the caller's own operating hub".
--
--   Concretely reproduced live on staging using two synthetic Personnel
--   fixtures (one home-hub KAN-HUB-01, one home-hub KAT-HUB-01):
--     - A Katsina-hub Personnel account staged a Kano-origin parcel at
--       origin hub via receive_parcel_at_origin_hub.
--     - The same Katsina-hub Personnel account froze/confirmed a Kano batch
--       it never created, receiving the Batch QR token.
--     - The same Katsina-hub Personnel account triggered onboard_batch
--       (the authoritative "physical departure" / IN_TRANSIT event) on a
--       Kano-origin batch.
--
--   This violates the 6-part authorization tuple (identity + role +
--   resource relationship + OPERATIONAL SCOPE + state + action) documented
--   in AGENTS.md and already enforced for the pickup domain (migration
--   20260817000020) and destination/reconciliation domain (migrations
--   20260827000025-27). The outbound batch domain (originally migration
--   20260817000007) never received equivalent hardening.
--
--   FIX: add an explicit v_personnel.operating_hub_id = <origin_hub_id>
--   check to every outbound batch-lifecycle RPC. No other behavior changes.
--   Forward-only migration; migrations 01-29 are not edited.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_batch(
  p_origin_hub_id UUID,
  p_destination_hub_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_corridor RECORD;
  v_ref TEXT;
  v_batch_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM p_origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: You may only create batches originating at your own operating hub.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_corridor
  FROM public.corridors
  WHERE origin_hub_id = p_origin_hub_id AND destination_hub_id = p_destination_hub_id AND is_active = TRUE;

  IF v_corridor IS NULL THEN
    RAISE EXCEPTION 'No active corridor found between origin and destination hubs.' USING ERRCODE = 'P0002';
  END IF;

  v_ref := public.generate_batch_reference();

  INSERT INTO public.batches (
    batch_reference, corridor_id, origin_hub_id, destination_hub_id,
    current_batch_state, created_by_personnel_id
  ) VALUES (
    v_ref, v_corridor.id, p_origin_hub_id, p_destination_hub_id, 'DRAFT', v_personnel.id
  )
  RETURNING id INTO v_batch_id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', v_batch_id, 'BATCH_CREATED', v_personnel.id, 'PERSONNEL', p_origin_hub_id,
    jsonb_build_object('batch_reference', v_ref, 'corridor_code', v_corridor.code)
  );

  RETURN jsonb_build_object(
    'success', true, 'batch_id', v_batch_id, 'batch_reference', v_ref,
    'corridor_code', v_corridor.code, 'status', 'DRAFT', 'manifest_parcel_count', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.add_parcel_to_batch(
  p_batch_id UUID,
  p_parcel_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Cannot modify non-draft batch (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_parcel.current_parcel_state NOT IN ('ORIGIN_HUB_STAGED', 'BATCH_LOCKED') THEN
    RAISE EXCEPTION 'Parcel is not staged at origin hub (current state: %)', v_parcel.current_parcel_state
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;
  IF v_shipment.corridor_id != v_batch.corridor_id THEN
    RAISE EXCEPTION 'Parcel destination corridor does not match batch corridor.' USING ERRCODE = '23514';
  END IF;

  IF EXISTS (SELECT 1 FROM public.batch_memberships WHERE batch_id = p_batch_id AND parcel_id = p_parcel_id AND is_active = TRUE) THEN
    RETURN jsonb_build_object('success', true, 'already_added', true, 'batch_id', p_batch_id, 'parcel_id', p_parcel_id, 'manifest_parcel_count', v_batch.manifest_parcel_count);
  END IF;

  IF EXISTS (SELECT 1 FROM public.batch_memberships WHERE parcel_id = p_parcel_id AND is_active = TRUE) THEN
    RAISE EXCEPTION 'Parcel is already assigned to another active batch.' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.batch_memberships (batch_id, parcel_id, added_by_personnel_id)
  VALUES (p_batch_id, p_parcel_id, v_personnel.id);

  UPDATE public.parcels SET current_parcel_state = 'BATCH_LOCKED' WHERE id = p_parcel_id;
  UPDATE public.batches SET manifest_parcel_count = manifest_parcel_count + 1 WHERE id = p_batch_id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'PARCEL_ADDED_TO_BATCH', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('parcel_id', p_parcel_id, 'delivery_code', v_shipment.delivery_code)
  );

  RETURN jsonb_build_object('success', true, 'already_added', false, 'batch_id', p_batch_id, 'parcel_id', p_parcel_id, 'manifest_parcel_count', v_batch.manifest_parcel_count + 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.remove_parcel_from_draft_batch(
  p_batch_id UUID,
  p_parcel_id UUID,
  p_reason TEXT DEFAULT 'Removed by personnel before confirmation'
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Cannot modify non-draft batch (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.batch_memberships
  SET is_active = FALSE, removed_at = NOW(), removed_by_personnel_id = v_personnel.id, removal_reason = p_reason
  WHERE batch_id = p_batch_id AND parcel_id = p_parcel_id AND is_active = TRUE;

  UPDATE public.parcels SET current_parcel_state = 'ORIGIN_HUB_STAGED' WHERE id = p_parcel_id;
  UPDATE public.batches SET manifest_parcel_count = GREATEST(0, manifest_parcel_count - 1) WHERE id = p_batch_id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'PARCEL_REMOVED_FROM_BATCH', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('parcel_id', p_parcel_id, 'reason', p_reason)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'parcel_id', p_parcel_id, 'manifest_parcel_count', GREATEST(0, v_batch.manifest_parcel_count - 1));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.confirm_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_active_count INT;
  v_qr_token TEXT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state = 'CONFIRMED' THEN
    RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'batch_reference', v_batch.batch_reference, 'batch_qr_token', v_batch.batch_qr_token, 'status', 'CONFIRMED', 'manifest_parcel_count', v_batch.manifest_parcel_count, 'already_confirmed', true);
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Only draft batches can be confirmed (current state: %)', v_batch.current_batch_state USING ERRCODE = '23514';
  END IF;

  SELECT COUNT(*) INTO v_active_count FROM public.batch_memberships WHERE batch_id = p_batch_id AND is_active = TRUE;
  IF v_active_count = 0 THEN
    RAISE EXCEPTION 'Cannot confirm empty batch. Add at least one parcel.' USING ERRCODE = '23514';
  END IF;

  v_qr_token := public.generate_batch_qr_token();

  UPDATE public.batches
  SET current_batch_state = 'CONFIRMED', batch_qr_token = v_qr_token, manifest_parcel_count = v_active_count,
      confirmed_by_personnel_id = v_personnel.id, confirmed_at = NOW()
  WHERE id = p_batch_id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'BATCH_CONFIRMED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('parcel_count', v_active_count, 'batch_qr_token', v_qr_token)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'batch_reference', v_batch.batch_reference, 'batch_qr_token', v_qr_token, 'status', 'CONFIRMED', 'manifest_parcel_count', v_active_count, 'already_confirmed', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.set_batch_transport_arrangement(
  p_batch_id UUID,
  p_provider_name TEXT,
  p_driver_name TEXT DEFAULT NULL,
  p_driver_phone TEXT DEFAULT NULL,
  p_vehicle_plate TEXT DEFAULT NULL,
  p_agreed_cost_amount INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_run_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state NOT IN ('DRAFT', 'CONFIRMED') THEN
    RAISE EXCEPTION 'Cannot alter transport on departed or completed batch.' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.transit_runs (
    corridor_id, driver_name, driver_phone, vehicle_plate_number, agreed_cost_amount, created_by_personnel_id
  ) VALUES (
    v_batch.corridor_id, p_driver_name, p_driver_phone, p_vehicle_plate, COALESCE(p_agreed_cost_amount, 0), v_personnel.id
  )
  RETURNING id INTO v_run_id;

  UPDATE public.batches SET transit_run_id = v_run_id WHERE id = p_batch_id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'TRANSPORT_ASSIGNED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('transit_run_id', v_run_id, 'provider_name', p_provider_name, 'driver_name', p_driver_name, 'agreed_cost_amount', p_agreed_cost_amount)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'transit_run_id', v_run_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.onboard_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state = 'ONBOARDED' THEN
    RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'status', 'ONBOARDED', 'already_onboarded', true);
  END IF;

  IF v_batch.current_batch_state != 'CONFIRMED' THEN
    RAISE EXCEPTION 'Batch must be CONFIRMED before it can be onboarded (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.batches
  SET current_batch_state = 'ONBOARDED', onboarded_by_personnel_id = v_personnel.id, onboarded_at = NOW()
  WHERE id = p_batch_id;

  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs SET status = 'DEPARTED', actual_departure_at = NOW() WHERE id = v_batch.transit_run_id;
  END IF;

  FOR v_parcel IN
    SELECT p.* FROM public.batch_memberships bm
    JOIN public.parcels p ON p.id = bm.parcel_id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels SET current_parcel_state = 'IN_TRANSIT' WHERE id = v_parcel.id;

    SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;
    UPDATE public.shipments SET current_status = 'IN_TRANSIT' WHERE id = v_shipment.id;

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'SHIPMENT', v_shipment.id, 'SHIPMENT_IN_TRANSIT', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
      jsonb_build_object('status', 'IN_TRANSIT', 'batch_id', p_batch_id)
    );
  END LOOP;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'BATCH_ONBOARDED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('batch_reference', v_batch.batch_reference)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'status', 'ONBOARDED', 'already_onboarded', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.receive_parcel_at_origin_hub(p_parcel_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_shipment.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This parcel does not originate at your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED' THEN
    RETURN jsonb_build_object('success', true, 'parcel_id', v_parcel.id, 'status', 'AT_ORIGIN_HUB', 'current_parcel_state', 'ORIGIN_HUB_STAGED', 'already_received', true);
  END IF;

  IF v_parcel.current_parcel_state != 'IN_CERELO_CUSTODY' THEN
    RAISE EXCEPTION 'Parcel is not in Cerelo custody (current state: %)', v_parcel.current_parcel_state USING ERRCODE = '23514';
  END IF;

  IF v_parcel.parcel_qr_token IS NULL THEN
    PERFORM public.ensure_parcel_qr(p_parcel_id);
  END IF;

  UPDATE public.parcels SET current_parcel_state = 'ORIGIN_HUB_STAGED', current_custody_type = 'HUB' WHERE id = p_parcel_id;
  UPDATE public.shipments SET current_status = 'AT_ORIGIN_HUB' WHERE id = v_shipment.id;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'PARCEL', p_parcel_id, 'PARCEL_RECEIVED_AT_ORIGIN_HUB', v_personnel.id, 'PERSONNEL', v_personnel.operating_hub_id,
    jsonb_build_object('shipment_id', v_shipment.id)
  );

  RETURN jsonb_build_object('success', true, 'parcel_id', v_parcel.id, 'status', 'AT_ORIGIN_HUB', 'current_parcel_state', 'ORIGIN_HUB_STAGED', 'already_received', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_batch(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_parcel_to_batch(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_parcel_from_draft_batch(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_batch_transport_arrangement(UUID, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.onboard_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_parcel_at_origin_hub(UUID) TO authenticated;
