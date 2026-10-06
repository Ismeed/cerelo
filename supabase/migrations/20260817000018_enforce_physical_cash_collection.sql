-- =============================================================================
-- Cerelo V1 — Physical Cash Collection Enforcement & Pricing Safety
-- Version: 20260817000018
-- Description:
--   1. Constrains payment_collections.collection_method to CASH only
--      (replaces the former CASH/BANK_TRANSFER check constraint).
--   2. Constrains payment_obligations.collection_method to CASH only.
--   3. Replaces record_physical_payment RPC with explicit server-side
--      CASH-only enforcement BEFORE the table write (defense-in-depth).
--   4. Adds pricing_rules.is_approved_for_production boolean column
--      (DEFAULT FALSE) as a production-activation gate.
--   5. Replaces get_delivery_quote and create_shipment_request to require
--      BOTH is_active=TRUE AND is_approved_for_production=TRUE.
--      Staging rows are patched to TRUE after migration; production rows
--      stay FALSE until management explicitly approves commercial pricing.
--
-- Do NOT edit migrations 01–17.
-- Schema remains identical across staging and production.
-- Data activation state diverges safely via is_approved_for_production.
-- =============================================================================

-- ─── 1. payment_collections: CASH-only constraint ────────────────────────────

ALTER TABLE public.payment_collections
  DROP CONSTRAINT IF EXISTS payment_collections_collection_method_check;

ALTER TABLE public.payment_collections
  ADD CONSTRAINT payment_collections_collection_method_cash_only
  CHECK (collection_method = 'CASH');

-- ─── 2. payment_obligations: CASH-only constraint ────────────────────────────

ALTER TABLE public.payment_obligations
  DROP CONSTRAINT IF EXISTS payment_obligations_collection_method_check;

ALTER TABLE public.payment_obligations
  ADD CONSTRAINT payment_obligations_collection_method_cash_only
  CHECK (collection_method = 'CASH');

-- ─── 3. pricing_rules: add is_approved_for_production gate ───────────────────

ALTER TABLE public.pricing_rules
  ADD COLUMN IF NOT EXISTS is_approved_for_production BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.pricing_rules.is_approved_for_production IS
  'Production activation gate. Bootstrap/placeholder pricing defaults to FALSE. '
  'Must be set TRUE by authorized admin after management sign-off on commercial '
  'fare schedule. Staging rows are patched TRUE separately to retain QA capability.';

-- ─── 4. record_physical_payment — CASH-only server enforcement ────────────────
-- Defense-in-depth: validates p_method='CASH' in RPC body BEFORE table write.
-- The table constraint (step 1) is the final hard stop.

CREATE OR REPLACE FUNCTION public.record_physical_payment(
  p_shipment_id     UUID,
  p_payer_party     TEXT,
  p_amount          INT,
  p_method          TEXT DEFAULT 'CASH',
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id           UUID := auth.uid();
  v_personnel         RECORD;
  v_shipment          RECORD;
  v_obligation        RECORD;
  v_existing_coll     RECORD;
  v_collection_id     UUID;
BEGIN
  -- 0. Enforce CASH-only — explicit server-side rejection before any DB write
  IF COALESCE(UPPER(TRIM(p_method)), 'CASH') != 'CASH' THEN
    RAISE EXCEPTION
      'Only physical CASH collection is supported in Cerelo V1. Received: %', p_method
      USING ERRCODE = '23514',
            HINT = 'Omit p_method or pass ''CASH''.';
  END IF;

  -- 1. Security: active Personnel required
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate payer party
  IF UPPER(TRIM(p_payer_party)) NOT IN ('SENDER', 'RECEIVER') THEN
    RAISE EXCEPTION 'Invalid payer party: %', p_payer_party USING ERRCODE = '23514';
  END IF;

  -- 3. Idempotency check
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_coll
    FROM public.payment_collections
    WHERE idempotency_key = TRIM(p_idempotency_key);

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success',       true,
        'collection_id', v_existing_coll.id,
        'status',        'COLLECTED',
        'is_duplicate',  true,
        'message',       'Payment collection already recorded with this idempotency key.'
      );
    END IF;
  END IF;

  -- 4. Lock shipment & validate obligation
  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_obligation
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id
    AND payer_party = UPPER(TRIM(p_payer_party))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No payment obligation found for % on this shipment.', p_payer_party
      USING ERRCODE = 'P0002';
  END IF;

  -- 5. Already collected — idempotent success
  IF v_obligation.status = 'COLLECTED' THEN
    RETURN jsonb_build_object(
      'success',          true,
      'status',           'COLLECTED',
      'already_collected', true,
      'message',          'Payment obligation is already fully collected.'
    );
  END IF;

  -- 6. Amount check
  IF p_amount <= 0 OR p_amount != v_obligation.expected_amount THEN
    RAISE EXCEPTION
      'Submitted payment amount (%) does not match expected obligation (%).',
      p_amount, v_obligation.expected_amount
      USING ERRCODE = '23514';
  END IF;

  -- 7. Record physical cash collection
  INSERT INTO public.payment_collections (
    payment_obligation_id,
    shipment_id,
    collected_by_personnel_id,
    payer_party,
    amount_collected,
    collection_method,
    idempotency_key
  ) VALUES (
    v_obligation.id,
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_payer_party)),
    p_amount,
    'CASH',
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_collection_id;

  -- 8. Update obligation
  UPDATE public.payment_obligations
  SET status                    = 'COLLECTED',
      collected_at              = NOW(),
      collection_method         = 'CASH',
      collected_by_personnel_id = v_personnel.id
  WHERE id = v_obligation.id;

  -- 9. Immutable audit event
  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type,
    actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'PAYMENT', p_shipment_id, 'PHYSICAL_PAYMENT_COLLECTED',
    v_personnel.id, 'PERSONNEL', v_shipment.destination_hub_id,
    jsonb_build_object(
      'payer_party', UPPER(TRIM(p_payer_party)),
      'amount',      p_amount,
      'method',      'CASH'
    )
  );

  RETURN jsonb_build_object(
    'success',          true,
    'collection_id',    v_collection_id,
    'status',           'COLLECTED',
    'payer_party',      UPPER(TRIM(p_payer_party)),
    'amount_collected', p_amount,
    'method',           'CASH'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- ─── 5. get_delivery_quote — require is_approved_for_production = TRUE ─────────

CREATE OR REPLACE FUNCTION public.get_delivery_quote(
  p_origin_city      TEXT,
  p_destination_city TEXT,
  p_size_tier_code   TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_corridor_id UUID;
  v_tier_id     UUID;
  v_price       INT;
  v_currency    TEXT;
  v_tier_name   TEXT;
  v_tier_desc   TEXT;
BEGIN
  -- 1. Resolve active corridor
  SELECT c.id INTO v_corridor_id
  FROM public.corridors c
  JOIN public.cities orig ON orig.id = c.origin_city_id
  JOIN public.cities dest ON dest.id = c.destination_city_id
  WHERE orig.name ILIKE p_origin_city
    AND dest.name ILIKE p_destination_city
    AND c.is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unsupported or inactive corridor: % to %',
      p_origin_city, p_destination_city
      USING ERRCODE = 'P0002';
  END IF;

  -- 2. Resolve active size tier
  SELECT id, name, description INTO v_tier_id, v_tier_name, v_tier_desc
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_size_tier_code))
    AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or inactive parcel size tier: %', p_size_tier_code
      USING ERRCODE = 'P0002';
  END IF;

  -- 3. Resolve production-approved pricing rule
  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id         = v_corridor_id
    AND parcel_size_tier_id = v_tier_id
    AND is_active           = TRUE
    AND is_approved_for_production = TRUE;

  IF NOT FOUND THEN
    -- Safe, non-leaking error. Client apps must render:
    -- "Pricing is not yet available on this route. Please try again later."
    RAISE EXCEPTION 'SERVICE_PRICING_NOT_ACTIVE'
      USING ERRCODE = 'P0002',
            DETAIL  = 'No approved pricing rule for corridor/size combination.',
            HINT    = 'An operator must approve commercial pricing before bookings can proceed.';
  END IF;

  RETURN jsonb_build_object(
    'corridor_id',          v_corridor_id,
    'size_tier_id',         v_tier_id,
    'size_tier_code',       UPPER(TRIM(p_size_tier_code)),
    'size_tier_name',       v_tier_name,
    'size_tier_description', v_tier_desc,
    'quoted_price_amount',  v_price,
    'currency',             v_currency
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 6. create_shipment_request — require is_approved_for_production = TRUE ────

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
  v_user_id                  UUID := auth.uid();
  v_customer                 RECORD;
  v_corridor                 RECORD;
  v_tier                     RECORD;
  v_price                    INT;
  v_currency                 TEXT;
  v_delivery_code            TEXT;
  v_shipment_id              UUID;
  v_parcel_id                UUID;
  v_sender_obligation        INT;
  v_receiver_obligation      INT;
  v_normalized_receiver_phone TEXT;
  v_existing_shipment        RECORD;
BEGIN
  -- 1. Authentication
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Customer profile + onboarding
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer profile not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_customer.onboarding_completed_at IS NULL THEN
    RAISE EXCEPTION 'Customer onboarding must be completed before requesting shipments.'
      USING ERRCODE = '23514';
  END IF;

  -- 3. Idempotency
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

  -- 4. Corridor resolution
  SELECT c.*, orig.name AS orig_name, dest.name AS dest_name
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

  -- 5. Size tier resolution
  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_parcel_size_code))
    AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_parcel_size_code
      USING ERRCODE = 'P0002';
  END IF;

  -- 6. Pricing — requires is_active AND is_approved_for_production
  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id         = v_corridor.id
    AND parcel_size_tier_id = v_tier.id
    AND is_active           = TRUE
    AND is_approved_for_production = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SERVICE_PRICING_NOT_ACTIVE: Booking unavailable — pricing for this corridor has not been approved for production.'
      USING ERRCODE = 'P0002';
  END IF;

  -- 7. Receiver validation
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

  -- 8. Payment mode & obligations
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
    IF p_sender_payment_amount IS NULL OR p_sender_payment_amount <= 0
       OR p_sender_payment_amount >= v_price THEN
      RAISE EXCEPTION
        'For Split Payment, sender amount must be strictly between 0 and total price (%)',
        v_price USING ERRCODE = '23514';
    END IF;
    v_sender_obligation   := p_sender_payment_amount;
    v_receiver_obligation := v_price - p_sender_payment_amount;
  END IF;

  -- 9. Delivery code
  v_delivery_code := public.generate_delivery_code();

  -- 10. Insert shipment
  INSERT INTO public.shipments (
    delivery_code, sender_customer_id, corridor_id,
    origin_city, destination_city, origin_hub_id, destination_hub_id,
    sender_name_snapshot, sender_phone_snapshot, sender_pickup_address_snapshot,
    receiver_name_snapshot, receiver_phone_snapshot, receiver_delivery_address_snapshot,
    delivery_instructions, landmark,
    quoted_price_amount, final_price_amount, currency, payment_mode,
    current_status, idempotency_key
  ) VALUES (
    v_delivery_code, v_user_id, v_corridor.id,
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

  -- 11. Insert parcel
  INSERT INTO public.parcels (
    shipment_id, sender_declared_size_id,
    category_description, current_parcel_state, current_custody_type
  ) VALUES (
    v_shipment_id, v_tier.id,
    COALESCE(NULLIF(TRIM(p_category_description), ''), 'General Goods'),
    'UNCONFIRMED', 'SENDER'
  )
  RETURNING id INTO v_parcel_id;

  -- 12. Payment obligations
  INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
  VALUES (
    v_shipment_id, 'SENDER', v_sender_obligation,
    CASE WHEN v_sender_obligation > 0 THEN 'PENDING' ELSE 'NOT_REQUIRED' END
  );
  INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
  VALUES (
    v_shipment_id, 'RECEIVER', v_receiver_obligation,
    CASE WHEN v_receiver_obligation > 0 THEN 'PENDING' ELSE 'NOT_REQUIRED' END
  );

  -- 13. Audit event
  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type,
    actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'SHIPMENT', v_shipment_id, 'SHIPMENT_REQUESTED',
    v_user_id, 'CUSTOMER', v_corridor.origin_hub_id,
    jsonb_build_object(
      'delivery_code', v_delivery_code,
      'route',         v_corridor.code,
      'payment_mode',  UPPER(TRIM(p_payment_mode)),
      'price',         v_price
    )
  );

  -- 14. Return sanitized result
  RETURN jsonb_build_object(
    'id',                  v_shipment_id,
    'delivery_code',       v_delivery_code,
    'current_status',      'REQUESTED',
    'origin_city',         v_corridor.orig_name,
    'destination_city',    v_corridor.dest_name,
    'quoted_price_amount', v_price,
    'final_price_amount',  v_price,
    'currency',            v_currency,
    'payment_mode',        UPPER(TRIM(p_payment_mode)),
    'sender_name_snapshot', v_customer.full_name,
    'receiver_name_snapshot', TRIM(p_receiver_name),
    'created_at',          NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 7. Grants ────────────────────────────────────────────────────────────────
GRANT EXECUTE ON FUNCTION
  public.record_physical_payment(UUID, TEXT, INT, TEXT, TEXT)
  TO authenticated;

GRANT EXECUTE ON FUNCTION
  public.get_delivery_quote(TEXT, TEXT, TEXT)
  TO authenticated, anon;

GRANT EXECUTE ON FUNCTION
  public.create_shipment_request(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT)
  TO authenticated;

-- =============================================================================
-- ENVIRONMENT DATA ACTIVATION NOTE (DO NOT REMOVE)
-- =============================================================================
-- STAGING:
--   After applying this migration on cerelo-staging, run:
--     UPDATE public.pricing_rules SET is_approved_for_production = TRUE;
--   This restores QA/test pricing capability without schema divergence.
--
-- PRODUCTION:
--   All pricing_rules rows default to is_approved_for_production = FALSE.
--   Production booking is blocked until management approves fares via:
--     UPDATE public.pricing_rules
--       SET is_approved_for_production = TRUE
--       WHERE id IN (<approved-rule-ids>);
--   This must be a deliberate, documented management action.
-- =============================================================================
