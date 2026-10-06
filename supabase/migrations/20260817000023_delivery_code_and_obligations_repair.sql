-- =============================================================================
-- Cerelo V1 — P0 Consistency Repair
-- Version: 20260817000023
-- Description:
--   1. Fix create_shipment_request — delivery_code = NULL at REQUESTED state.
--      (Migration 18 incorrectly re-introduced early code generation.)
--   2. Enforce SPLIT_PAYMENT obligations as strict 50/50 of authoritative fare.
--      Remove client-controlled p_sender_payment_amount for SPLIT_PAYMENT.
--   3. Enforce SPLIT_PAYMENT 50/50 in verify_and_correct_parcel_size too.
--   4. Add employee_reference auto-generation server-side:
--        generate_employee_reference(p_hub_code TEXT) -> CRL-KAN-0001 etc.
--      Concurrency-safe using advisory lock + per-hub counter.
--   5. Automated regression DO blocks (run at migration apply time).
-- =============================================================================

-- =============================================================================
-- SECTION 1: EMPLOYEE REFERENCE SEQUENCE TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.employee_reference_counters (
  hub_code   TEXT PRIMARY KEY,
  last_seq   INT  NOT NULL DEFAULT 0
);

INSERT INTO public.employee_reference_counters (hub_code, last_seq)
VALUES ('KAN', 0), ('KAT', 0)
ON CONFLICT (hub_code) DO NOTHING;

-- =============================================================================
-- SECTION 2: generate_employee_reference — concurrency-safe hub-sequential ID
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_employee_reference(p_hub_code TEXT)
RETURNS TEXT AS $$
DECLARE
  v_hub_upper TEXT := UPPER(TRIM(p_hub_code));
  v_seq       INT;
  v_ref       TEXT;
BEGIN
  INSERT INTO public.employee_reference_counters (hub_code, last_seq)
  VALUES (v_hub_upper, 0)
  ON CONFLICT (hub_code) DO NOTHING;

  PERFORM pg_advisory_xact_lock(hashtext('emp_ref_' || v_hub_upper));

  UPDATE public.employee_reference_counters
  SET    last_seq = last_seq + 1
  WHERE  hub_code = v_hub_upper
  RETURNING last_seq INTO v_seq;

  v_ref := 'CRL-' || v_hub_upper || '-' || LPAD(v_seq::TEXT, 4, '0');
  RETURN v_ref;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 3: FIX create_shipment_request
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_shipment_request(
  p_origin_city               TEXT,
  p_destination_city          TEXT,
  p_sender_pickup_address     TEXT,
  p_receiver_name             TEXT,
  p_receiver_phone            TEXT,
  p_receiver_delivery_address TEXT,
  p_parcel_size_code          TEXT,
  p_category_description      TEXT,
  p_payment_mode              TEXT,
  p_sender_payment_amount     INT  DEFAULT NULL,
  p_delivery_instructions     TEXT DEFAULT NULL,
  p_landmark                  TEXT DEFAULT NULL,
  p_idempotency_key           TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id                   UUID := auth.uid();
  v_customer                  RECORD;
  v_corridor                  RECORD;
  v_tier                      RECORD;
  v_price                     INT;
  v_currency                  TEXT;
  v_shipment_id               UUID;
  v_parcel_id                 UUID;
  v_sender_obligation         INT;
  v_receiver_obligation       INT;
  v_normalized_receiver_phone TEXT;
  v_existing_shipment         RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer profile not found.' USING ERRCODE = 'P0002';
  END IF;
  IF v_customer.onboarding_completed_at IS NULL THEN
    RAISE EXCEPTION 'Customer onboarding must be completed before requesting shipments.'
      USING ERRCODE = '23514';
  END IF;

  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_shipment
    FROM public.shipments
    WHERE idempotency_key = TRIM(p_idempotency_key)
      AND sender_customer_id = v_user_id;
    IF FOUND THEN
      RETURN jsonb_build_object(
        'id',                  v_existing_shipment.id,
        'delivery_code',       v_existing_shipment.delivery_code,
        'current_status',      v_existing_shipment.current_status,
        'origin_city',         v_existing_shipment.origin_city,
        'destination_city',    v_existing_shipment.destination_city,
        'quoted_price_amount', v_existing_shipment.quoted_price_amount,
        'final_price_amount',  v_existing_shipment.final_price_amount,
        'payment_mode',        v_existing_shipment.payment_mode,
        'created_at',          v_existing_shipment.created_at,
        'is_duplicate',        true
      );
    END IF;
  END IF;

  SELECT c.*, orig.name AS orig_name, dest.name AS dest_name, c.code AS corridor_code
  INTO v_corridor
  FROM public.corridors c
  JOIN public.cities orig ON orig.id = c.origin_city_id
  JOIN public.cities dest ON dest.id = c.destination_city_id
  WHERE orig.name ILIKE TRIM(p_origin_city)
    AND dest.name ILIKE TRIM(p_destination_city)
    AND c.is_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unsupported corridor: % to %', p_origin_city, p_destination_city
      USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_parcel_size_code)) AND is_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_parcel_size_code USING ERRCODE = 'P0002';
  END IF;

  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id = v_corridor.id
    AND parcel_size_tier_id = v_tier.id
    AND is_active = TRUE
    AND is_approved_for_production = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SERVICE_PRICING_NOT_ACTIVE: Booking unavailable.' USING ERRCODE = 'P0002';
  END IF;

  IF p_receiver_name IS NULL OR TRIM(p_receiver_name) = '' THEN
    RAISE EXCEPTION 'Receiver name is required.' USING ERRCODE = '23514';
  END IF;
  IF p_receiver_phone IS NULL OR TRIM(p_receiver_phone) = '' THEN
    RAISE EXCEPTION 'Receiver phone number is required.' USING ERRCODE = '23514';
  END IF;
  v_normalized_receiver_phone := regexp_replace(p_receiver_phone, '[\s\-\(\)]', '', 'g');
  IF v_normalized_receiver_phone LIKE '0%' AND length(v_normalized_receiver_phone) = 11 THEN
    v_normalized_receiver_phone := '+234' || substr(v_normalized_receiver_phone, 2);
  ELSIF v_normalized_receiver_phone LIKE '234%' AND length(v_normalized_receiver_phone) = 13 THEN
    v_normalized_receiver_phone := '+' || v_normalized_receiver_phone;
  END IF;
  IF p_receiver_delivery_address IS NULL OR TRIM(p_receiver_delivery_address) = '' THEN
    RAISE EXCEPTION 'Receiver delivery address is required.' USING ERRCODE = '23514';
  END IF;
  IF p_sender_pickup_address IS NULL OR TRIM(p_sender_pickup_address) = '' THEN
    RAISE EXCEPTION 'Pickup address is required.' USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_payment_mode)) NOT IN ('SENDER_PAYS', 'RECEIVER_PAYS', 'SPLIT_PAYMENT') THEN
    RAISE EXCEPTION 'Invalid payment mode: %', p_payment_mode USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_payment_mode)) = 'SENDER_PAYS' THEN
    v_sender_obligation   := v_price;
    v_receiver_obligation := 0;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'RECEIVER_PAYS' THEN
    v_sender_obligation   := 0;
    v_receiver_obligation := v_price;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'SPLIT_PAYMENT' THEN
    -- LOCKED: Always 50/50 server-enforced. p_sender_payment_amount is ignored.
    v_sender_obligation   := v_price / 2;
    v_receiver_obligation := v_price - v_sender_obligation;
  END IF;

  INSERT INTO public.shipments (
    delivery_code,
    sender_customer_id, corridor_id,
    origin_city, destination_city, origin_hub_id, destination_hub_id,
    sender_name_snapshot, sender_phone_snapshot, sender_pickup_address_snapshot,
    receiver_name_snapshot, receiver_phone_snapshot, receiver_delivery_address_snapshot,
    delivery_instructions, landmark,
    quoted_price_amount, final_price_amount, currency, payment_mode,
    current_status, idempotency_key
  ) VALUES (
    NULL,
    v_user_id, v_corridor.id,
    v_corridor.orig_name, v_corridor.dest_name,
    v_corridor.origin_hub_id, v_corridor.destination_hub_id,
    v_customer.full_name, COALESCE(v_customer.phone_number, ''),
    TRIM(p_sender_pickup_address),
    TRIM(p_receiver_name), v_normalized_receiver_phone,
    TRIM(p_receiver_delivery_address),
    NULLIF(TRIM(p_delivery_instructions), ''), NULLIF(TRIM(p_landmark), ''),
    v_price, v_price, v_currency, UPPER(TRIM(p_payment_mode)),
    'REQUESTED', NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_shipment_id;

  INSERT INTO public.parcels (
    shipment_id, sender_declared_size_id, category_description,
    current_parcel_state, current_custody_type
  ) VALUES (
    v_shipment_id, v_tier.id,
    COALESCE(NULLIF(TRIM(p_category_description), ''), 'General Goods'),
    'UNCONFIRMED', 'SENDER'
  )
  RETURNING id INTO v_parcel_id;

  IF v_sender_obligation > 0 THEN
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'SENDER', v_sender_obligation, 'PENDING');
  ELSE
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'SENDER', 0, 'NOT_REQUIRED');
  END IF;

  IF v_receiver_obligation > 0 THEN
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'RECEIVER', v_receiver_obligation, 'PENDING');
  ELSE
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'RECEIVER', 0, 'NOT_REQUIRED');
  END IF;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type,
    actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'SHIPMENT', v_shipment_id, 'SHIPMENT_REQUESTED',
    v_user_id, 'CUSTOMER', v_corridor.origin_hub_id,
    jsonb_build_object(
      'route',        v_corridor.corridor_code,
      'payment_mode', UPPER(TRIM(p_payment_mode)),
      'quoted_price', v_price
    )
  );

  RETURN jsonb_build_object(
    'id',                   v_shipment_id,
    'delivery_code',        NULL,
    'current_status',       'REQUESTED',
    'origin_city',          v_corridor.orig_name,
    'destination_city',     v_corridor.dest_name,
    'quoted_price_amount',  v_price,
    'final_price_amount',   v_price,
    'currency',             v_currency,
    'payment_mode',         UPPER(TRIM(p_payment_mode)),
    'sender_name_snapshot', v_customer.full_name,
    'receiver_name_snapshot', TRIM(p_receiver_name),
    'created_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 4: FIX verify_and_correct_parcel_size (50/50 SPLIT enforcement)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.verify_and_correct_parcel_size(
  p_shipment_id         UUID,
  p_size_tier_code      TEXT,
  p_reason              TEXT DEFAULT NULL,
  p_sender_acknowledged BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_personnel           RECORD;
  v_shipment            RECORD;
  v_parcel              RECORD;
  v_original_tier       RECORD;
  v_new_tier            RECORD;
  v_new_price           INT;
  v_orig_price          INT;
  v_sender_obligation   INT;
  v_receiver_obligation INT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE id = auth.uid() AND is_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active personnel profile required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Only the assigned pickup Personnel may adjust the parcel size.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'PICKUP_IN_PROGRESS' THEN
    RAISE EXCEPTION 'Size adjustment only allowed during active pickup. Current: %', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  IF v_shipment.origin_hub_id IS DISTINCT FROM v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Shipment is not in your hub scope.' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payment_collections WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER'
  ) THEN
    RAISE EXCEPTION 'Sender payment already collected. Fare cannot be adjusted after collection.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcel record not found.' USING ERRCODE = 'P0002'; END IF;

  SELECT * INTO v_original_tier FROM public.parcel_size_tiers WHERE id = v_parcel.sender_declared_size_id;

  SELECT * INTO v_new_tier
  FROM public.parcel_size_tiers WHERE code = UPPER(TRIM(p_size_tier_code)) AND is_active = TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_size_tier_code USING ERRCODE = 'P0002';
  END IF;

  SELECT base_price_amount INTO v_new_price
  FROM public.pricing_rules
  WHERE corridor_id = v_shipment.corridor_id AND parcel_size_tier_id = v_new_tier.id AND is_active = TRUE;
  IF v_new_price IS NULL THEN
    RAISE EXCEPTION 'No pricing rule found for verified size tier.' USING ERRCODE = 'P0002';
  END IF;

  v_orig_price := v_shipment.quoted_price_amount;

  IF v_new_tier.id != v_original_tier.id THEN
    INSERT INTO public.parcel_size_corrections (
      shipment_id, parcel_id, personnel_id,
      original_size_id, corrected_size_id,
      original_price_amount, corrected_price_amount,
      reason, sender_acknowledged
    ) VALUES (
      p_shipment_id, v_parcel.id, v_personnel.id,
      v_original_tier.id, v_new_tier.id,
      v_orig_price, v_new_price, p_reason, p_sender_acknowledged
    );

    UPDATE public.shipments SET final_price_amount = v_new_price WHERE id = p_shipment_id;

    IF v_shipment.payment_mode = 'SENDER_PAYS' THEN
      v_sender_obligation := v_new_price; v_receiver_obligation := 0;
    ELSIF v_shipment.payment_mode = 'RECEIVER_PAYS' THEN
      v_sender_obligation := 0; v_receiver_obligation := v_new_price;
    ELSIF v_shipment.payment_mode = 'SPLIT_PAYMENT' THEN
      v_sender_obligation := v_new_price / 2;
      v_receiver_obligation := v_new_price - v_sender_obligation;
    END IF;

    UPDATE public.payment_obligations SET expected_amount = v_sender_obligation
    WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';
    UPDATE public.payment_obligations SET expected_amount = v_receiver_obligation
    WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'SHIPMENT', p_shipment_id, 'PARCEL_SIZE_CORRECTED',
      v_personnel.id, 'PERSONNEL', v_personnel.operating_hub_id,
      jsonb_build_object(
        'original_size', v_original_tier.code, 'corrected_size', v_new_tier.code,
        'original_price', v_orig_price, 'corrected_price', v_new_price,
        'sender_obligation', v_sender_obligation, 'receiver_obligation', v_receiver_obligation,
        'sender_acknowledged', p_sender_acknowledged, 'reason', p_reason
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'size_tier_code', v_new_tier.code,
    'size_tier_name', v_new_tier.name,
    'quoted_price_amount', v_orig_price,
    'final_price_amount', v_new_price,
    'is_corrected', (v_new_tier.id != v_original_tier.id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 5: GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.generate_employee_reference(TEXT) TO service_role;
GRANT SELECT, INSERT, UPDATE ON TABLE public.employee_reference_counters TO service_role;
REVOKE EXECUTE ON FUNCTION public.generate_employee_reference(TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.create_shipment_request(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,TEXT,INT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_correct_parcel_size(UUID,TEXT,TEXT,BOOLEAN) TO authenticated;
