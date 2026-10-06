-- =============================================================================
-- Cerelo V1 — Migration 25: Destination Batch Inbound Authorization & Reconciliation
-- Version: 20260827000025
-- Description: 
--   1. Directional Batch Authorization (Destination Hub check).
--   2. Receive Batch RPC with strict destination hub validation.
--   3. Manifest Reconciliation RPCs with hub isolation.
--   4. Delete / Cancel Draft Batch RPCs.
--   5. Batch Resolution by QR or Reference RPC.
--   6. Extended get_personnel_batches with hub IDs and transport metadata.
--   7. Ready-for-delivery queue destination hub isolation.
-- =============================================================================

-- 1. Receive Destination Batch RPC with Strict Directional Hub Check
CREATE OR REPLACE FUNCTION public.receive_destination_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
BEGIN
  -- Security check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- Validate Batch
  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Directional Hub Authorization: Only destination hub personnel can receive inbound batch
  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to receive batch at this destination hub (hub mismatch: expected %, got %).',
      v_batch.destination_hub_id, v_personnel.operating_hub_id
      USING ERRCODE = '42501';
  END IF;

  -- Idempotency check
  IF v_batch.current_batch_state = 'DESTINATION_RECEIVED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'batch_id', p_batch_id,
      'status', 'DESTINATION_RECEIVED',
      'already_received', true
    );
  END IF;

  IF v_batch.current_batch_state != 'ONBOARDED' THEN
    RAISE EXCEPTION 'Batch is not in transit (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  -- Atomic State Update: Batch Arrived at Destination
  UPDATE public.batches
  SET current_batch_state = 'DESTINATION_RECEIVED',
      updated_at = NOW()
  WHERE id = p_batch_id;

  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs
    SET status = 'ARRIVED',
        actual_arrival_at = NOW(),
        updated_at = NOW()
    WHERE id = v_batch.transit_run_id;
  END IF;

  -- Update member parcels and shipments to intermediate destination arrived state
  FOR v_parcel IN
    SELECT p.*
    FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'DESTINATION_HUB_STAGED',
        current_custody_type = 'HUB',
        updated_at = NOW()
    WHERE id = v_parcel.id;

    -- Record intermediate customer tracking event: Arrived at Destination Hub (Processing)
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
      v_parcel.shipment_id,
      'SHIPMENT_ARRIVED_AT_DESTINATION_HUB',
      v_personnel.id,
      'PERSONNEL',
      v_batch.destination_hub_id,
      jsonb_build_object(
        'status', 'ARRIVED_AT_DESTINATION_HUB',
        'hub_id', v_batch.destination_hub_id,
        'batch_reference', v_batch.batch_reference
      )
    );
  END LOOP;

  -- Log Batch Destination Received Event
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
    'BATCH',
    p_batch_id,
    'BATCH_DESTINATION_RECEIVED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object(
      'batch_reference', v_batch.batch_reference,
      'destination_hub_id', v_batch.destination_hub_id,
      'received_by', v_personnel.full_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'status', 'DESTINATION_RECEIVED',
    'already_received', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Reconcile Individual Batch Parcel RPC with Destination Hub Check
CREATE OR REPLACE FUNCTION public.reconcile_batch_parcel(
  p_batch_id UUID,
  p_parcel_id UUID,
  p_disposition TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
BEGIN
  -- Security check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to reconcile batch at this destination hub.'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Upsert disposition
  INSERT INTO public.batch_reconciliation_records (
    batch_id,
    parcel_id,
    disposition,
    reconciled_by_personnel_id,
    notes,
    reconciled_at
  )
  VALUES (
    p_batch_id,
    p_parcel_id,
    UPPER(p_disposition),
    v_personnel.id,
    p_notes,
    NOW()
  )
  ON CONFLICT (batch_id, parcel_id)
  DO UPDATE SET
    disposition = UPPER(p_disposition),
    notes = p_notes,
    reconciled_at = NOW(),
    reconciled_by_personnel_id = v_personnel.id;

  -- If marked PRESENT, ensure parcel custody is HUB and state is DESTINATION_HUB_STAGED
  IF UPPER(p_disposition) = 'PRESENT' THEN
    UPDATE public.parcels
    SET current_parcel_state = 'DESTINATION_HUB_STAGED',
        current_custody_type = 'HUB',
        updated_at = NOW()
    WHERE id = p_parcel_id;
  END IF;

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
    'PARCEL',
    p_parcel_id,
    'PARCEL_RECONCILED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object('batch_id', p_batch_id, 'disposition', UPPER(p_disposition))
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'parcel_id', p_parcel_id,
    'disposition', UPPER(p_disposition)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Complete Batch Reconciliation RPC
CREATE OR REPLACE FUNCTION public.complete_batch_reconciliation(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_expected_count INT;
  v_reconciled_count INT;
  v_rec RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to complete reconciliation for this batch.'
      USING ERRCODE = '42501';
  END IF;

  SELECT COUNT(*) INTO v_expected_count
  FROM public.batch_memberships
  WHERE batch_id = p_batch_id AND is_active = TRUE;

  SELECT COUNT(*) INTO v_reconciled_count
  FROM public.batch_reconciliation_records
  WHERE batch_id = p_batch_id;

  IF v_reconciled_count < v_expected_count THEN
    RAISE EXCEPTION 'Cannot complete reconciliation: % of % expected parcels reconciled.', v_reconciled_count, v_expected_count
      USING ERRCODE = '23514';
  END IF;

  -- Update batch state to RECONCILED
  UPDATE public.batches
  SET current_batch_state = 'RECONCILED',
      updated_at = NOW()
  WHERE id = p_batch_id;

  -- For each parcel marked PRESENT, transition shipment to ARRIVED_DESTINATION (Ready for Delivery)
  FOR v_rec IN
    SELECT brr.*, p.shipment_id
    FROM public.batch_reconciliation_records brr
    JOIN public.parcels p ON p.id = brr.parcel_id
    WHERE brr.batch_id = p_batch_id AND brr.disposition = 'PRESENT'
  LOOP
    UPDATE public.shipments
    SET current_status = 'ARRIVED_DESTINATION',
        updated_at = NOW()
    WHERE id = v_rec.shipment_id;

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
      v_rec.shipment_id,
      'SHIPMENT_ARRIVED_DESTINATION',
      v_personnel.id,
      'PERSONNEL',
      v_batch.destination_hub_id,
      jsonb_build_object('status', 'ARRIVED_DESTINATION', 'batch_id', p_batch_id)
    );
  END LOOP;

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
    'BATCH',
    p_batch_id,
    'BATCH_RECONCILIATION_COMPLETED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object('reconciled_count', v_reconciled_count)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'status', 'RECONCILED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Delete Empty Draft Batch RPC
CREATE OR REPLACE FUNCTION public.delete_draft_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_member_count INT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.origin_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Personnel can only delete draft batches originating from their home hub.'
      USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Only draft batches can be deleted (current state: %).', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  SELECT COUNT(*) INTO v_member_count
  FROM public.batch_memberships
  WHERE batch_id = p_batch_id AND is_active = TRUE;

  IF v_member_count > 0 THEN
    RAISE EXCEPTION 'Cannot delete draft batch with active parcels. Use cancel_draft_batch instead.'
      USING ERRCODE = '23514';
  END IF;

  DELETE FROM public.batches WHERE id = p_batch_id;

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'deleted', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Cancel Draft Batch with Parcels RPC
CREATE OR REPLACE FUNCTION public.cancel_draft_batch(
  p_batch_id UUID,
  p_reason TEXT DEFAULT 'Draft cancelled by personnel'
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.origin_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Personnel can only cancel draft batches originating from their home hub.'
      USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Only draft batches can be cancelled (current state: %).', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  -- Release all member parcels back to origin hub staged pool
  FOR v_parcel IN
    SELECT p.*
    FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'ORIGIN_HUB_STAGED',
        current_custody_type = 'HUB',
        updated_at = NOW()
    WHERE id = v_parcel.id;
  END LOOP;

  -- Deactivate memberships
  UPDATE public.batch_memberships
  SET is_active = FALSE,
      removed_at = NOW(),
      removed_by_personnel_id = v_personnel.id,
      removal_reason = p_reason
  WHERE batch_id = p_batch_id AND is_active = TRUE;

  -- Mark batch cancelled
  UPDATE public.batches
  SET current_batch_state = 'CANCELLED',
      manifest_parcel_count = 0,
      updated_at = NOW()
  WHERE id = p_batch_id;

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
    'BATCH',
    p_batch_id,
    'BATCH_CANCELLED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object('reason', p_reason, 'batch_reference', v_batch.batch_reference)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'cancelled', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Resolve Batch by QR Token or Batch Reference RPC
CREATE OR REPLACE FUNCTION public.resolve_batch_by_qr_or_ref(p_token_or_ref TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_cleaned TEXT;
  v_batch RECORD;
  v_corridor RECORD;
  v_origin_city RECORD;
  v_destination_city RECORD;
  v_origin_hub RECORD;
  v_destination_hub RECORD;
  v_transit_run RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  v_cleaned := TRIM(p_token_or_ref);

  SELECT * INTO v_batch
  FROM public.batches
  WHERE batch_qr_token = v_cleaned
     OR UPPER(batch_reference) = UPPER(v_cleaned)
  LIMIT 1;

  IF v_batch IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'BATCH_NOT_FOUND');
  END IF;

  SELECT * INTO v_corridor FROM public.corridors WHERE id = v_batch.corridor_id;
  SELECT * INTO v_origin_city FROM public.cities WHERE id = v_corridor.origin_city_id;
  SELECT * INTO v_destination_city FROM public.cities WHERE id = v_corridor.destination_city_id;
  SELECT * INTO v_origin_hub FROM public.operating_hubs WHERE id = v_batch.origin_hub_id;
  SELECT * INTO v_destination_hub FROM public.operating_hubs WHERE id = v_batch.destination_hub_id;
  SELECT * INTO v_transit_run FROM public.transit_runs WHERE id = v_batch.transit_run_id;

  RETURN jsonb_build_object(
    'is_valid', true,
    'id', v_batch.id,
    'batch_reference', v_batch.batch_reference,
    'batch_qr_token', v_batch.batch_qr_token,
    'current_batch_state', v_batch.current_batch_state,
    'corridor_code', v_corridor.code,
    'origin_city', v_origin_city.name,
    'destination_city', v_destination_city.name,
    'origin_hub_id', v_batch.origin_hub_id,
    'origin_hub_code', v_origin_hub.code,
    'origin_hub_name', v_origin_hub.name,
    'destination_hub_id', v_batch.destination_hub_id,
    'destination_hub_code', v_destination_hub.code,
    'destination_hub_name', v_destination_hub.name,
    'manifest_parcel_count', v_batch.manifest_parcel_count,
    'driver_name', v_transit_run.driver_name,
    'driver_phone', v_transit_run.driver_phone,
    'vehicle_plate_number', v_transit_run.vehicle_plate_number,
    'actual_departure_at', v_transit_run.actual_departure_at,
    'created_at', v_batch.created_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Extended get_personnel_batches RPC
CREATE OR REPLACE FUNCTION public.get_personnel_batches(p_status TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'id', b.id,
      'batch_reference', b.batch_reference,
      'batch_qr_token', b.batch_qr_token,
      'current_batch_state', b.current_batch_state,
      'corridor_code', c.code,
      'origin_city', oc.name,
      'destination_city', dc.name,
      'origin_hub_id', b.origin_hub_id,
      'origin_hub_code', oh.code,
      'destination_hub_id', b.destination_hub_id,
      'destination_hub_code', dh.code,
      'manifest_parcel_count', b.manifest_parcel_count,
      'driver_name', tr.driver_name,
      'driver_phone', tr.driver_phone,
      'vehicle_plate_number', tr.vehicle_plate_number,
      'actual_departure_at', tr.actual_departure_at,
      'confirmed_at', b.confirmed_at,
      'onboarded_at', b.onboarded_at,
      'created_at', b.created_at
    ) ORDER BY b.created_at DESC
  ) INTO v_result
  FROM public.batches b
  JOIN public.corridors c ON c.id = b.corridor_id
  JOIN public.cities oc ON oc.id = c.origin_city_id
  JOIN public.cities dc ON dc.id = c.destination_city_id
  JOIN public.operating_hubs oh ON oh.id = b.origin_hub_id
  JOIN public.operating_hubs dh ON dh.id = b.destination_hub_id
  LEFT JOIN public.transit_runs tr ON tr.id = b.transit_run_id
  WHERE (p_status IS NULL OR b.current_batch_state = UPPER(p_status))
    AND b.current_batch_state != 'CANCELLED';

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Hardened Ready-for-delivery Queue RPC with Destination Hub Scope
CREATE OR REPLACE FUNCTION public.get_ready_for_delivery_queue()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'shipment_id', s.id,
      'parcel_id', p.id,
      'delivery_code', s.delivery_code,
      'parcel_qr_token', p.parcel_qr_token,
      'current_status', s.current_status,
      'origin_city', s.origin_city,
      'destination_city', s.destination_city,
      'sender_name', s.sender_name_snapshot,
      'sender_phone', s.sender_phone_snapshot,
      'receiver_name', s.receiver_name_snapshot,
      'receiver_phone', s.receiver_phone_snapshot,
      'receiver_delivery_address', s.receiver_delivery_address_snapshot,
      'landmark', s.landmark,
      'delivery_instructions', s.delivery_instructions,
      'confirmed_size_code', pst.code,
      'confirmed_size_name', pst.name,
      'category_description', p.category_description,
      'payment_mode', s.payment_mode,
      'final_price_amount', s.final_price_amount,
      'receiver_payment_status', COALESCE(po.status, 'NOT_REQUIRED'),
      'receiver_due_amount', COALESCE(po.expected_amount, 0),
      'created_at', s.created_at
    ) ORDER BY s.created_at ASC
  ) INTO v_result
  FROM public.shipments s
  JOIN public.parcels p ON p.shipment_id = s.id
  JOIN public.parcel_size_tiers pst ON pst.id = COALESCE(p.confirmed_size_id, p.sender_declared_size_id)
  LEFT JOIN public.payment_obligations po ON po.shipment_id = s.id AND po.payer_party = 'RECEIVER'
  WHERE s.current_status IN ('ARRIVED_DESTINATION', 'OUT_FOR_DELIVERY')
    AND s.destination_hub_id = v_personnel.operating_hub_id;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
