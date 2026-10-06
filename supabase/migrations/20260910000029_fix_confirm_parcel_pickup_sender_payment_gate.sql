-- =============================================================================
-- Cerelo V1 — P0 Fix: confirm_parcel_pickup Sender-Payment Gate Bypass
-- Version: 20260910000029
-- Description:
--   RUNTIME-VERIFIED DEFECT (Phase 3 autonomous staging audit, 2026-09-10):
--   confirm_parcel_pickup allowed Confirm Parcel (custody transfer + Delivery
--   Code generation) to succeed for a SENDER_PAYS shipment whose SENDER
--   payment_obligations row was still PENDING and had zero payment_collections
--   rows — i.e. no cash was ever recorded as collected. Reproduced live on
--   staging shipment e59522f8-e60a-49c7-b457-5832fe1f4a87 (synthetic fixture).
--
--   ROOT CAUSE:
--   Same class of bug already diagnosed and fixed for mark_delivered in
--   migration 20260817000019: the fragile
--     SELECT * INTO v_record ...;
--     IF v_record IS NOT NULL AND ... THEN RAISE EXCEPTION ...
--   pattern inside a SECURITY DEFINER function is unreliable when RLS
--   evaluation order is involved — a SELECT INTO a RECORD that matches zero
--   visible rows silently yields NULL instead of erroring, so the guard is
--   skipped rather than tripped. confirm_parcel_pickup (migration
--   20260817000020) was written after that fix existed but never received
--   the same hardening.
--
--   FIX (mirrors migration 20260817000019's remedy exactly):
--     (a) SET LOCAL row_security = off — internal precondition reads inside
--         this SECURITY DEFINER function must not be filtered; the function
--         already independently authenticates and authorizes the caller as
--         the assigned pickup Personnel before this point.
--     (b) Replace the SELECT-INTO-RECORD/IS NOT NULL pattern with
--         PERFORM ... IF FOUND for the sender-payment precondition —
--         an unambiguous row-existence test.
--
--   No other behavior of confirm_parcel_pickup is changed. This is a
--   forward-only migration; migrations 01-28 are not edited.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.confirm_parcel_pickup(
  p_shipment_id UUID,
  p_verified_size_code TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
  v_tier RECORD;
  v_latest_verification RECORD;
  v_sender_expected INT;
  v_delivery_code TEXT;
BEGIN
  -- Bypass RLS for internal precondition checks inside this SECURITY DEFINER
  -- function. The function is called only by authenticated, role-verified
  -- Personnel (checked immediately below); internal reads (payment_obligations,
  -- receiver_verifications, shipments, parcels) must not be filtered by RLS,
  -- which is scoped for direct client access, not for this server-side gate.
  SET LOCAL row_security = off;

  -- 1. Security: active personnel with home hub
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Lock shipment
  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Idempotency check: if already confirmed
  IF v_shipment.current_status = 'PARCEL_CONFIRMED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'shipment_id', v_shipment.id,
      'delivery_code', v_shipment.delivery_code,
      'status', 'PARCEL_CONFIRMED',
      'already_confirmed', true
    );
  END IF;

  -- Owner check
  IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned pickup personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'PICKUP_IN_PROGRESS' THEN
    RAISE EXCEPTION 'Shipment is not in pickup state (current: %)', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  -- 3. Verify Receiver Call
  SELECT * INTO v_latest_verification
  FROM public.receiver_verifications
  WHERE shipment_id = p_shipment_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_latest_verification IS NULL OR v_latest_verification.outcome != 'VERIFIED' THEN
    RAISE EXCEPTION 'Receiver verification call is mandatory before Confirm Parcel.' USING ERRCODE = '23514';
  END IF;

  -- 4. Verify Sender Payment — unambiguous PERFORM/IF FOUND precondition test.
  --    Only fires when an obligation actually exists with expected_amount > 0
  --    and is not yet COLLECTED. NOT_REQUIRED / zero-amount obligations
  --    (RECEIVER_PAYS shipments) are correctly skipped.
  SELECT expected_amount INTO v_sender_expected
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id
    AND payer_party = 'SENDER'
    AND expected_amount > 0;

  IF FOUND AND v_sender_expected > 0 THEN
    PERFORM 1 FROM public.payment_obligations
    WHERE shipment_id = p_shipment_id
      AND payer_party = 'SENDER'
      AND expected_amount > 0
      AND status = 'COLLECTED';

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Required sender payment of % kobo must be collected before Confirm Parcel.', v_sender_expected
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- 5. Resolve Verified Size Tier
  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_verified_size_code)) AND is_active = TRUE;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid verified size tier: %', p_verified_size_code USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;

  -- 6. Generate Delivery Code
  v_delivery_code := public.generate_delivery_code_for_shipment(p_shipment_id);

  -- 7. Atomic Custody Transfer
  UPDATE public.parcels
  SET confirmed_size_id = v_tier.id,
      current_parcel_state = 'IN_CERELO_CUSTODY',
      current_custody_type = 'PERSONNEL',
      custody_holder_id = v_personnel.id
  WHERE id = v_parcel.id;

  UPDATE public.shipments
  SET current_status = 'PARCEL_CONFIRMED'
  WHERE id = p_shipment_id;

  -- 8. Append Operational Events
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
    'PARCEL_CONFIRMED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'confirmed_size', v_tier.code,
      'delivery_code', v_delivery_code,
      'custody_holder', v_personnel.full_name
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
    v_parcel.id,
    'CUSTODY_TRANSFERRED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'from_custody', 'SENDER',
      'to_custody', 'PERSONNEL',
      'custody_holder_id', v_personnel.id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', p_shipment_id,
    'delivery_code', v_delivery_code,
    'status', 'PARCEL_CONFIRMED',
    'confirmed_size_code', v_tier.code,
    'confirmed_size_name', v_tier.name,
    'final_price_amount', v_shipment.final_price_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

GRANT EXECUTE ON FUNCTION public.confirm_parcel_pickup(UUID, TEXT, TEXT) TO authenticated;
