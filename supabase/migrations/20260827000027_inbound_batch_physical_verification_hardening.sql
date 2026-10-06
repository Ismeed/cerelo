-- =============================================================================
-- Cerelo V1 — Migration 27: Inbound Batch Physical-Verification UX & Server Hardening
-- Version: 20260827000027
-- Description:
--   1. Incoming Projection Least-Privilege Hardening:
--      - get_personnel_batches hides batch_reference and batch_qr_token for inbound in-transit batches.
--      - get_personnel_batches exposes driver_phone for authorized hub handoff coordination.
--   2. Physical Identifier Resolution RPC:
--      - resolve_inbound_batch_for_receipt validates physical Batch QR or Batch Code.
--      - Reveals human-readable batch reference only upon successful physical code resolution.
--   3. Server-Side Physical Verification Invariant on Batch Receipt:
--      - receive_destination_batch requires physical Batch QR or Batch Code identifier.
--      - Direct parameter bypass without physical identifier is strictly rejected.
-- =============================================================================

-- 1. Inbound Projection Least-Privilege Hardening on get_personnel_batches
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
      -- LEAST PRIVILEGE: Mask Batch Reference for incoming in-transit batches until physically scanned/resolved
      'batch_reference', CASE 
        WHEN b.destination_hub_id = v_personnel.operating_hub_id 
             AND b.origin_hub_id != v_personnel.operating_hub_id 
             AND b.current_batch_state = 'ONBOARDED' 
        THEN NULL 
        ELSE b.batch_reference 
      END,
      -- LEAST PRIVILEGE: Never leak Batch QR token in batch lists
      'batch_qr_token', CASE 
        WHEN b.destination_hub_id = v_personnel.operating_hub_id 
             AND b.origin_hub_id != v_personnel.operating_hub_id 
             AND b.current_batch_state = 'ONBOARDED' 
        THEN NULL 
        ELSE b.batch_qr_token 
      END,
      'current_batch_state', b.current_batch_state,
      'corridor_code', c.code,
      'origin_hub_id', b.origin_hub_id,
      'destination_hub_id', b.destination_hub_id,
      'origin_hub_code', oh.code,
      'destination_hub_code', dh.code,
      'origin_city', oc.name,
      'destination_city', dc.name,
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
  JOIN public.operating_hubs oh ON oh.id = b.origin_hub_id
  JOIN public.operating_hubs dh ON dh.id = b.destination_hub_id
  JOIN public.cities oc ON oc.id = oh.city_id
  JOIN public.cities dc ON dc.id = dh.city_id
  LEFT JOIN public.transit_runs tr ON tr.id = b.transit_run_id
  WHERE (
    -- Hub Isolation: Only show batches originated at OR destined for personnel operating hub
    b.origin_hub_id = v_personnel.operating_hub_id 
    OR b.destination_hub_id = v_personnel.operating_hub_id
  )
  AND (p_status IS NULL OR b.current_batch_state = UPPER(p_status));

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Physical Identifier Resolution RPC for Inbound Batches
CREATE OR REPLACE FUNCTION public.resolve_inbound_batch_for_receipt(p_batch_identifier TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_clean_token TEXT;
  v_origin_hub RECORD;
  v_destination_hub RECORD;
  v_origin_city RECORD;
  v_destination_city RECORD;
  v_transit_run RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF p_batch_identifier IS NULL OR pg_catalog.btrim(p_batch_identifier) = '' THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'EMPTY_IDENTIFIER');
  END IF;

  v_clean_token := pg_catalog.upper(pg_catalog.btrim(p_batch_identifier));
  IF v_clean_token LIKE 'CERELO://BATCH/%' THEN
    v_clean_token := pg_catalog.substr(v_clean_token, 16);
  END IF;

  SELECT * INTO v_batch 
  FROM public.batches 
  WHERE batch_qr_token = v_clean_token OR batch_reference = v_clean_token;

  IF v_batch IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'BATCH_NOT_FOUND');
  END IF;

  -- Directional Hub Authorization: Only destination hub personnel can resolve for receipt
  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to receive batch at this destination hub (hub mismatch).'
      USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_origin_hub FROM public.operating_hubs WHERE id = v_batch.origin_hub_id;
  SELECT * INTO v_destination_hub FROM public.operating_hubs WHERE id = v_batch.destination_hub_id;
  SELECT * INTO v_origin_city FROM public.cities WHERE id = v_origin_hub.city_id;
  SELECT * INTO v_destination_city FROM public.cities WHERE id = v_destination_hub.city_id;
  SELECT * INTO v_transit_run FROM public.transit_runs WHERE id = v_batch.transit_run_id;

  RETURN jsonb_build_object(
    'is_valid', true,
    'batch_id', v_batch.id,
    -- Revealed only upon physical resolution:
    'batch_reference', v_batch.batch_reference,
    'current_batch_state', v_batch.current_batch_state,
    'origin_hub_code', v_origin_hub.code,
    'origin_hub_name', v_origin_hub.name,
    'origin_city', v_origin_city.name,
    'destination_hub_code', v_destination_hub.code,
    'destination_hub_name', v_destination_hub.name,
    'destination_city', v_destination_city.name,
    'manifest_parcel_count', v_batch.manifest_parcel_count,
    'driver_name', v_transit_run.driver_name,
    'driver_phone', v_transit_run.driver_phone,
    'vehicle_plate_number', v_transit_run.vehicle_plate_number,
    'actual_departure_at', v_transit_run.actual_departure_at,
    'is_eligible_for_receipt', (v_batch.current_batch_state = 'ONBOARDED'),
    'already_received', (v_batch.current_batch_state IN ('DESTINATION_RECEIVED', 'RECONCILING', 'RECONCILED'))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Inbound Batch Receipt RPC Enforcing Physical Identifier Verification
CREATE OR REPLACE FUNCTION public.receive_destination_batch_verified(
  p_batch_identifier TEXT,
  p_batch_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_clean_token TEXT;
  v_rec RECORD;
BEGIN
  -- Security check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF p_batch_identifier IS NULL OR pg_catalog.btrim(p_batch_identifier) = '' THEN
    RAISE EXCEPTION 'Physical Batch QR or Batch Code verification required to receive inbound batch.'
      USING ERRCODE = '23514';
  END IF;

  v_clean_token := pg_catalog.upper(pg_catalog.btrim(p_batch_identifier));
  IF v_clean_token LIKE 'CERELO://BATCH/%' THEN
    v_clean_token := pg_catalog.substr(v_clean_token, 16);
  END IF;

  -- Lookup batch by physical identifier
  SELECT * INTO v_batch 
  FROM public.batches 
  WHERE batch_qr_token = v_clean_token OR batch_reference = v_clean_token;

  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found matching provided physical identifier.'
      USING ERRCODE = 'P0002';
  END IF;

  -- If explicit batch_id was provided, verify it matches
  IF p_batch_id IS NOT NULL AND v_batch.id != p_batch_id THEN
    RAISE EXCEPTION 'Provided Batch identifier does not match expected Batch ID.'
      USING ERRCODE = '23514';
  END IF;

  -- Directional Hub Authorization: Only destination hub personnel can receive
  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to receive batch at this destination hub (hub mismatch: expected %, got %).',
      v_batch.destination_hub_id, v_personnel.operating_hub_id
      USING ERRCODE = '42501';
  END IF;

  -- Idempotency check: If already received, return success without re-mutating
  IF v_batch.current_batch_state IN ('DESTINATION_RECEIVED', 'RECONCILING', 'RECONCILED') THEN
    RETURN jsonb_build_object(
      'success', true,
      'batch_id', v_batch.id,
      'batch_reference', v_batch.batch_reference,
      'status', v_batch.current_batch_state,
      'already_received', true
    );
  END IF;

  IF v_batch.current_batch_state != 'ONBOARDED' THEN
    RAISE EXCEPTION 'Cannot receive batch: Current state is %, expected ONBOARDED.', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  -- 1. Update Batch state to DESTINATION_RECEIVED
  UPDATE public.batches
  SET current_batch_state = 'DESTINATION_RECEIVED',
      updated_at = NOW()
  WHERE id = v_batch.id;

  -- 2. Update Transit Run status to ARRIVED
  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs
    SET status = 'ARRIVED',
        actual_arrival_at = NOW(),
        updated_at = NOW()
    WHERE id = v_batch.transit_run_id;
  END IF;

  -- 3. Update all Member Parcels to DESTINATION_HUB_STAGED and HUB custody
  FOR v_rec IN
    SELECT bm.parcel_id, p.shipment_id
    FROM public.batch_memberships bm
    JOIN public.parcels p ON p.id = bm.parcel_id
    WHERE bm.batch_id = v_batch.id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'DESTINATION_HUB_STAGED',
        current_custody_type = 'HUB',
        updated_at = NOW()
    WHERE id = v_rec.parcel_id;

    -- Operational event for customer tracking
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
      'SHIPMENT_ARRIVED_AT_DESTINATION_HUB',
      v_personnel.id,
      'PERSONNEL',
      v_batch.destination_hub_id,
      jsonb_build_object('status', 'ARRIVED_AT_DESTINATION_HUB', 'batch_id', v_batch.id)
    );
  END LOOP;

  -- 4. Batch Arrival Operational Event
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
    v_batch.id,
    'BATCH_DESTINATION_RECEIVED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object(
      'batch_reference', v_batch.batch_reference,
      'transit_run_id', v_batch.transit_run_id,
      'parcel_count', v_batch.manifest_parcel_count
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', v_batch.id,
    'batch_reference', v_batch.batch_reference,
    'status', 'DESTINATION_RECEIVED',
    'already_received', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Overload receive_destination_batch to delegate to verified implementation
CREATE OR REPLACE FUNCTION public.receive_destination_batch(p_batch_identifier TEXT)
RETURNS JSONB AS $$
BEGIN
  RETURN public.receive_destination_batch_verified(p_batch_identifier, NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.receive_destination_batch(p_batch_id UUID)
RETURNS JSONB AS $$
BEGIN
  -- Strict guard: Calling receive with just a raw batch_id without physical identifier is forbidden
  RAISE EXCEPTION 'Physical Batch QR or Batch Code verification required to receive inbound batch. Direct batch UUID receive is rejected.'
    USING ERRCODE = '23514';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissions
GRANT EXECUTE ON FUNCTION public.resolve_inbound_batch_for_receipt(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_destination_batch_verified(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_destination_batch(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_destination_batch(UUID) TO authenticated;
