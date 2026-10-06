-- =============================================================================
-- Cerelo V1 — Parcel QR Identity & Origin Hub Processing Migration
-- Version: 20260817000006
-- Description: Parcel QR generation, secure resolution, Delivery Code fallback,
--              origin hub physical receipt transaction, and Ready for Batch read models.
-- =============================================================================

-- =============================================================================
-- SECTION 1: PARCEL QR TOKEN GENERATOR
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_parcel_qr_token()
RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_seg1 TEXT := '';
  v_seg2 TEXT := '';
  v_seg3 TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..4 LOOP
    v_seg1 := v_seg1 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    v_seg2 := v_seg2 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    v_seg3 := v_seg3 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
  END LOOP;
  RETURN 'PQR-' || v_seg1 || '-' || v_seg2 || '-' || v_seg3;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- =============================================================================
-- SECTION 2: ENSURE PARCEL QR RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.ensure_parcel_qr(p_parcel_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_parcel RECORD;
  v_token TEXT;
  v_collision_count INT := 0;
BEGIN
  -- 1. Security check: active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Parcel exists and is confirmed
  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_parcel.current_parcel_state = 'UNCONFIRMED' THEN
    RAISE EXCEPTION 'Cannot generate QR for unconfirmed parcel.' USING ERRCODE = '23514';
  END IF;

  -- If QR already exists, return it (idempotent)
  IF v_parcel.parcel_qr_token IS NOT NULL THEN
    RETURN v_parcel.parcel_qr_token;
  END IF;

  -- Generate unique token with collision safety
  LOOP
    v_token := public.generate_parcel_qr_token();
    BEGIN
      UPDATE public.parcels
      SET parcel_qr_token = v_token
      WHERE id = p_parcel_id;
      EXIT; -- Success
    EXCEPTION WHEN unique_violation THEN
      v_collision_count := v_collision_count + 1;
      IF v_collision_count > 10 THEN
        RAISE EXCEPTION 'Failed to generate unique parcel QR token.' USING ERRCODE = '23505';
      END IF;
    END;
  END LOOP;

  -- Record operational event
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
    'PARCEL_QR_GENERATED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object('parcel_qr_token', v_token)
  );

  RETURN v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 3: RESOLVE PARCEL BY QR / DELIVERY CODE RPCS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.resolve_parcel_by_qr(p_qr_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
  v_size RECORD;
  v_clean_token TEXT;
BEGIN
  -- 1. Security check: active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF p_qr_token IS NULL OR TRIM(p_qr_token) = '' THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'INVALID_QR_TOKEN');
  END IF;

  v_clean_token := UPPER(TRIM(p_qr_token));
  -- Strip URI prefix if present (e.g. cerelo://parcel/PQR-...)
  IF v_clean_token LIKE 'CERELO://PARCEL/%' THEN
    v_clean_token := substr(v_clean_token, 17);
  END IF;

  SELECT * INTO v_parcel
  FROM public.parcels
  WHERE parcel_qr_token = v_clean_token;

  IF v_parcel IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'PARCEL_NOT_FOUND');
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;
  SELECT * INTO v_size FROM public.parcel_size_tiers WHERE id = COALESCE(v_parcel.confirmed_size_id, v_parcel.sender_declared_size_id);

  RETURN jsonb_build_object(
    'is_valid', true,
    'parcel_id', v_parcel.id,
    'shipment_id', v_shipment.id,
    'delivery_code', v_shipment.delivery_code,
    'parcel_qr_token', v_parcel.parcel_qr_token,
    'current_parcel_state', v_parcel.current_parcel_state,
    'current_status', v_shipment.current_status,
    'origin_city', v_shipment.origin_city,
    'destination_city', v_shipment.destination_city,
    'origin_hub_id', v_shipment.origin_hub_id,
    'destination_hub_id', v_shipment.destination_hub_id,
    'sender_name', v_shipment.sender_name_snapshot,
    'receiver_name', v_shipment.receiver_name_snapshot,
    'confirmed_size_code', v_size.code,
    'confirmed_size_name', v_size.name,
    'category_description', v_parcel.category_description,
    'final_price_amount', v_shipment.final_price_amount,
    'payment_mode', v_shipment.payment_mode,
    'is_hub_received', (v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED'),
    'is_ready_for_batch', (v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delivery Code Fallback Resolver
CREATE OR REPLACE FUNCTION public.resolve_parcel_by_delivery_code(p_delivery_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
  v_size RECORD;
  v_clean_code TEXT;
BEGIN
  -- 1. Security check: active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF p_delivery_code IS NULL OR TRIM(p_delivery_code) = '' THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'INVALID_DELIVERY_CODE');
  END IF;

  v_clean_code := UPPER(TRIM(p_delivery_code));

  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE delivery_code = v_clean_code;

  IF v_shipment IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'SHIPMENT_NOT_FOUND');
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = v_shipment.id;
  SELECT * INTO v_size FROM public.parcel_size_tiers WHERE id = COALESCE(v_parcel.confirmed_size_id, v_parcel.sender_declared_size_id);

  RETURN jsonb_build_object(
    'is_valid', true,
    'parcel_id', v_parcel.id,
    'shipment_id', v_shipment.id,
    'delivery_code', v_shipment.delivery_code,
    'parcel_qr_token', v_parcel.parcel_qr_token,
    'current_parcel_state', v_parcel.current_parcel_state,
    'current_status', v_shipment.current_status,
    'origin_city', v_shipment.origin_city,
    'destination_city', v_shipment.destination_city,
    'origin_hub_id', v_shipment.origin_hub_id,
    'destination_hub_id', v_shipment.destination_hub_id,
    'sender_name', v_shipment.sender_name_snapshot,
    'receiver_name', v_shipment.receiver_name_snapshot,
    'confirmed_size_code', v_size.code,
    'confirmed_size_name', v_size.name,
    'category_description', v_parcel.category_description,
    'final_price_amount', v_shipment.final_price_amount,
    'payment_mode', v_shipment.payment_mode,
    'is_hub_received', (v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED'),
    'is_ready_for_batch', (v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: RECEIVE PARCEL AT ORIGIN HUB RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.receive_parcel_at_origin_hub(p_parcel_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  -- 1. Security check: active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Parcel
  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;

  -- Idempotency check: If already staged at this origin hub, return success
  IF v_parcel.current_parcel_state = 'ORIGIN_HUB_STAGED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'parcel_id', v_parcel.id,
      'status', 'AT_ORIGIN_HUB',
      'current_parcel_state', 'ORIGIN_HUB_STAGED',
      'already_received', true
    );
  END IF;

  IF v_parcel.current_parcel_state != 'IN_CERELO_CUSTODY' THEN
    RAISE EXCEPTION 'Parcel is not in Cerelo custody (current state: %)', v_parcel.current_parcel_state
      USING ERRCODE = '23514';
  END IF;

  -- Ensure QR token exists
  IF v_parcel.parcel_qr_token IS NULL THEN
    PERFORM public.ensure_parcel_qr(p_parcel_id);
  END IF;

  -- 3. Atomic State Updates: Origin Hub Staged
  UPDATE public.parcels
  SET current_parcel_state = 'ORIGIN_HUB_STAGED',
      current_custody_type = 'HUB'
  WHERE id = p_parcel_id;

  UPDATE public.shipments
  SET current_status = 'AT_ORIGIN_HUB'
  WHERE id = v_shipment.id;

  -- 4. Append Operational Events
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
    'ORIGIN_HUB_RECEIVED',
    v_personnel.id,
    'PERSONNEL',
    COALESCE(v_personnel.operating_hub_id, v_shipment.origin_hub_id),
    jsonb_build_object(
      'hub_id', v_personnel.operating_hub_id,
      'received_by', v_personnel.full_name
    )
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
    'PARCEL',
    p_parcel_id,
    'CUSTODY_TRANSFERRED',
    v_personnel.id,
    'PERSONNEL',
    COALESCE(v_personnel.operating_hub_id, v_shipment.origin_hub_id),
    jsonb_build_object(
      'from_custody', 'PERSONNEL',
      'to_custody', 'HUB',
      'hub_id', v_personnel.operating_hub_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'parcel_id', p_parcel_id,
    'status', 'AT_ORIGIN_HUB',
    'current_parcel_state', 'ORIGIN_HUB_STAGED',
    'already_received', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 5: READY FOR BATCH READ MODEL RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_ready_for_batch_parcels()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  -- 1. Security check: active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Select ORIGIN_HUB_STAGED parcels scoped to Personnel's origin hub
  SELECT jsonb_agg(
    jsonb_build_object(
      'parcel_id', p.id,
      'shipment_id', s.id,
      'delivery_code', s.delivery_code,
      'parcel_qr_token', p.parcel_qr_token,
      'origin_city', s.origin_city,
      'destination_city', s.destination_city,
      'origin_hub_id', s.origin_hub_id,
      'destination_hub_id', s.destination_hub_id,
      'declared_size_code', pst.code,
      'confirmed_size_code', COALESCE(cst.code, pst.code),
      'confirmed_size_name', COALESCE(cst.name, pst.name),
      'category_description', p.category_description,
      'current_parcel_state', p.current_parcel_state,
      'created_at', p.created_at
    ) ORDER BY p.created_at ASC
  ) INTO v_result
  FROM public.parcels p
  JOIN public.shipments s ON s.id = p.shipment_id
  JOIN public.parcel_size_tiers pst ON pst.id = p.sender_declared_size_id
  LEFT JOIN public.parcel_size_tiers cst ON cst.id = p.confirmed_size_id
  WHERE p.current_parcel_state = 'ORIGIN_HUB_STAGED'
    AND (
      v_personnel.operating_hub_id IS NULL
      OR s.origin_hub_id = v_personnel.operating_hub_id
      OR s.origin_city ILIKE (SELECT name FROM public.cities WHERE id = (SELECT city_id FROM public.operating_hubs WHERE id = v_personnel.operating_hub_id))
    );

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.ensure_parcel_qr(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_parcel_by_qr(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_parcel_by_delivery_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_parcel_at_origin_hub(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ready_for_batch_parcels() TO authenticated;
