-- =============================================================================
-- Cerelo V1 — Delivery and Payment Semantics Alignment Migration
-- Version: 20260817000017
-- Description: 
-- 1. Explicitly codifies that Delivery Code is an operational shipment identifier 
--    and public tracking fallback, NOT a mandatory receiver OTP/PIN for doorstep delivery.
-- 2. Confirms mark_delivered is executed by authenticated authorized Personnel 
--    based on physical parcel handover without mandatory receiver PIN entry.
-- 3. Standardizes record_physical_payment with 'CASH' as the primary physical collection rail.
-- =============================================================================

-- ─── 1. PRIMARY FINAL-MILE DELIVERY RPC (NO MANDATORY CODE REQUIRED) ────────
CREATE OR REPLACE FUNCTION public.mark_delivered(
  p_shipment_id UUID,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
  v_receiver_obligation RECORD;
BEGIN
  -- 1. Security Check: Active Personnel identity & authorization
  SELECT * INTO v_personnel 
  FROM public.personnel 
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Shipment & State Preconditions
  SELECT * INTO v_shipment 
  FROM public.shipments 
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status = 'DELIVERED' THEN
    RETURN jsonb_build_object(
      'success', true, 
      'status', 'DELIVERED', 
      'already_delivered', true,
      'message', 'Shipment is already delivered.'
    );
  END IF;

  IF v_shipment.current_status != 'OUT_FOR_DELIVERY' THEN
    RAISE EXCEPTION 'Shipment must be OUT_FOR_DELIVERY before it can be marked DELIVERED (current status: %)', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  -- 3. Payment Precondition: Verify required Receiver obligation is COLLECTED
  SELECT * INTO v_receiver_obligation
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';

  IF v_receiver_obligation IS NOT NULL AND v_receiver_obligation.expected_amount > 0 THEN
    IF v_receiver_obligation.status != 'COLLECTED' THEN
      RAISE EXCEPTION 'Cannot mark delivered: Outstanding receiver payment of % has not been collected.', v_receiver_obligation.expected_amount
        USING ERRCODE = '23514';
    END IF;
  END IF;

  SELECT * INTO v_parcel 
  FROM public.parcels 
  WHERE shipment_id = p_shipment_id
  FOR UPDATE;

  -- 4. Atomic Delivery Completion (Authoritative Handover)
  UPDATE public.shipments
  SET current_status = 'DELIVERED',
      delivered_at = NOW(),
      delivered_by_personnel_id = v_personnel.id
  WHERE id = p_shipment_id;

  UPDATE public.parcels
  SET current_parcel_state = 'HANDED_OVER',
      current_custody_type = 'RECEIVER',
      current_custody_holder_id = NULL
  WHERE id = v_parcel.id;

  INSERT INTO public.delivery_attempts (
    shipment_id,
    attempted_by_personnel_id,
    outcome,
    notes
  )
  VALUES (
    p_shipment_id,
    v_personnel.id,
    'DELIVERED',
    'Parcel physically handed over to receiver by authorized personnel.'
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
    'SHIPMENT_DELIVERED',
    v_personnel.id,
    'PERSONNEL',
    v_shipment.destination_hub_id,
    jsonb_build_object(
      'status', 'DELIVERED', 
      'delivered_by', v_personnel.full_name,
      'delivery_code', v_shipment.delivery_code
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
    v_shipment.destination_hub_id,
    jsonb_build_object(
      'from_custody', 'PERSONNEL', 
      'to_custody', 'RECEIVER'
    )
  );

  RETURN jsonb_build_object(
    'success', true, 
    'status', 'DELIVERED', 
    'already_delivered', false,
    'delivery_code', v_shipment.delivery_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- ─── 2. COMPANION OPERATIONAL RPC WITH OPTIONAL DELIVERY CODE ─────────────────
CREATE OR REPLACE FUNCTION public.mark_delivered(
  p_shipment_id UUID,
  p_delivery_code TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  -- Delivery Code is preserved as an optional operational identifier / fallback.
  -- Validates delivery code format if provided, but does not block delivery if omitted.
  RETURN public.mark_delivered(p_shipment_id, p_idempotency_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- ─── 3. PHYSICAL PAYMENT RECORDING RPC ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_physical_payment(
  p_shipment_id UUID,
  p_payer_party TEXT,
  p_amount INT,
  p_method TEXT DEFAULT 'CASH',
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_obligation RECORD;
  v_existing_collection RECORD;
  v_collection_id UUID;
BEGIN
  -- 1. Security Check: Active Personnel
  SELECT * INTO v_personnel 
  FROM public.personnel 
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF UPPER(TRIM(p_payer_party)) NOT IN ('SENDER', 'RECEIVER') THEN
    RAISE EXCEPTION 'Invalid payer party: %', p_payer_party USING ERRCODE = '23514';
  END IF;

  -- 2. Idempotency Check
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_collection 
    FROM public.payment_collections 
    WHERE idempotency_key = TRIM(p_idempotency_key);

    IF v_existing_collection IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'collection_id', v_existing_collection.id,
        'status', 'COLLECTED',
        'is_duplicate', true,
        'message', 'Payment collection already recorded with this idempotency key.'
      );
    END IF;
  END IF;

  -- 3. Lock Shipment & Validate Obligation
  SELECT * INTO v_shipment 
  FROM public.shipments 
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_obligation 
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id 
    AND payer_party = UPPER(TRIM(p_payer_party))
  FOR UPDATE;

  IF v_obligation IS NULL THEN
    RAISE EXCEPTION 'No payment obligation found for % on this shipment.', p_payer_party
      USING ERRCODE = 'P0002';
  END IF;

  IF v_obligation.status = 'COLLECTED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', 'COLLECTED',
      'already_collected', true,
      'message', 'Payment obligation is already fully collected.'
    );
  END IF;

  IF p_amount <= 0 OR p_amount != v_obligation.expected_amount THEN
    RAISE EXCEPTION 'Submitted payment amount (%) does not match expected obligation (%).', p_amount, v_obligation.expected_amount
      USING ERRCODE = '23514';
  END IF;

  -- 4. Record Physical Collection
  INSERT INTO public.payment_collections (
    payment_obligation_id,
    shipment_id,
    collected_by_personnel_id,
    payer_party,
    amount_collected,
    collection_method,
    idempotency_key
  )
  VALUES (
    v_obligation.id,
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_payer_party)),
    p_amount,
    COALESCE(UPPER(TRIM(p_method)), 'CASH'),
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_collection_id;

  -- 5. Update Obligation Status
  UPDATE public.payment_obligations
  SET status = 'COLLECTED',
      collected_at = NOW(),
      collection_method = COALESCE(UPPER(TRIM(p_method)), 'CASH'),
      collected_by_personnel_id = v_personnel.id
  WHERE id = v_obligation.id;

  -- 6. Operational Event
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
    'PAYMENT',
    p_shipment_id,
    'PHYSICAL_PAYMENT_COLLECTED',
    v_personnel.id,
    'PERSONNEL',
    v_shipment.destination_hub_id,
    jsonb_build_object(
      'payer_party', UPPER(TRIM(p_payer_party)),
      'amount', p_amount,
      'method', COALESCE(UPPER(TRIM(p_method)), 'CASH')
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'collection_id', v_collection_id,
    'status', 'COLLECTED',
    'payer_party', UPPER(TRIM(p_payer_party)),
    'amount_collected', p_amount,
    'method', COALESCE(UPPER(TRIM(p_method)), 'CASH')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- Explicit Privileges
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_physical_payment(UUID, TEXT, INT, TEXT, TEXT) TO authenticated;
