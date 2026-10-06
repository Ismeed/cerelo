-- =============================================================================
-- Cerelo V1 — Personnel Pickup Domain & Confirm Parcel Migration
-- Version: 20260817000005
-- Description: Personnel pickup queue, receiver verification records, parcel size
--              correction, physical payment recording, and atomic Confirm Parcel custody transfer.
-- =============================================================================

-- =============================================================================
-- SECTION 1: OPERATIONAL PICKUP TABLES
-- =============================================================================

-- Receiver phone verification calls conducted during pickup
CREATE TABLE IF NOT EXISTS public.receiver_verifications (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id    UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  personnel_id   UUID NOT NULL REFERENCES public.personnel(id),
  outcome        TEXT NOT NULL CHECK (outcome IN (
                   'VERIFIED', 'NO_ANSWER', 'INVALID_NUMBER',
                   'UNAWARE_OR_DISPUTED', 'DETAILS_NEED_CORRECTION'
                 )),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_receiver_verifications_shipment
  ON public.receiver_verifications(shipment_id);

-- Parcel size corrections performed during physical inspection
CREATE TABLE IF NOT EXISTS public.parcel_size_corrections (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id            UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  parcel_id              UUID NOT NULL REFERENCES public.parcels(id) ON DELETE CASCADE,
  personnel_id           UUID NOT NULL REFERENCES public.personnel(id),
  original_size_id       UUID NOT NULL REFERENCES public.parcel_size_tiers(id),
  corrected_size_id      UUID NOT NULL REFERENCES public.parcel_size_tiers(id),
  original_price_amount  INT NOT NULL CHECK (original_price_amount >= 0),
  corrected_price_amount INT NOT NULL CHECK (corrected_price_amount >= 0),
  reason                 TEXT,
  sender_acknowledged    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Physical cash & bank transfer collection records
CREATE TABLE IF NOT EXISTS public.payment_collections (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_obligation_id     UUID NOT NULL REFERENCES public.payment_obligations(id),
  shipment_id               UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  collected_by_personnel_id UUID NOT NULL REFERENCES public.personnel(id),
  payer_party               TEXT NOT NULL CHECK (payer_party IN ('SENDER', 'RECEIVER')),
  amount_collected          INT NOT NULL CHECK (amount_collected > 0),
  collection_method         TEXT NOT NULL DEFAULT 'CASH' CHECK (collection_method IN ('CASH', 'BANK_TRANSFER')),
  idempotency_key           TEXT UNIQUE,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_collections_shipment
  ON public.payment_collections(shipment_id);

-- Pickup exceptions and failed attempts
CREATE TABLE IF NOT EXISTS public.pickup_exceptions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id    UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  personnel_id   UUID NOT NULL REFERENCES public.personnel(id),
  reason         TEXT NOT NULL CHECK (reason IN (
                   'SENDER_UNAVAILABLE', 'UNACCEPTABLE_PARCEL',
                   'PRICE_REJECTED', 'RECEIVER_VERIFICATION_FAILED',
                   'PAYMENT_REFUSED', 'OTHER'
                 )),
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Custody tracking columns on parcels table if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'parcels' AND column_name = 'custody_holder_id'
  ) THEN
    ALTER TABLE public.parcels ADD COLUMN custody_holder_id UUID REFERENCES public.personnel(id);
  END IF;
END $$;

-- Enable RLS
ALTER TABLE public.receiver_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcel_size_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickup_exceptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "receiver_verifications: personnel read"
  ON public.receiver_verifications FOR SELECT
  USING ((auth.jwt()->>'role') IN ('personnel', 'admin'));

CREATE POLICY "parcel_size_corrections: personnel read"
  ON public.parcel_size_corrections FOR SELECT
  USING ((auth.jwt()->>'role') IN ('personnel', 'admin'));

CREATE POLICY "payment_collections: personnel read"
  ON public.payment_collections FOR SELECT
  USING ((auth.jwt()->>'role') IN ('personnel', 'admin'));

CREATE POLICY "pickup_exceptions: personnel read"
  ON public.pickup_exceptions FOR SELECT
  USING ((auth.jwt()->>'role') IN ('personnel', 'admin'));

-- =============================================================================
-- SECTION 2: PERSONNEL WORK QUEUE RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_personnel_pickup_queue()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  -- Security check: Must be active Personnel
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- Select REQUESTED shipments scoped to Personnel's operating hub/city
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', s.id,
      'delivery_code', s.delivery_code,
      'current_status', s.current_status,
      'origin_city', s.origin_city,
      'destination_city', s.destination_city,
      'sender_name_snapshot', s.sender_name_snapshot,
      'sender_phone_snapshot', s.sender_phone_snapshot,
      'sender_pickup_address_snapshot', s.sender_pickup_address_snapshot,
      'landmark', s.landmark,
      'delivery_instructions', s.delivery_instructions,
      'receiver_name_snapshot', s.receiver_name_snapshot,
      'receiver_phone_snapshot', s.receiver_phone_snapshot,
      'receiver_delivery_address_snapshot', s.receiver_delivery_address_snapshot,
      'declared_size_code', pst.code,
      'declared_size_name', pst.name,
      'category_description', p.category_description,
      'payment_mode', s.payment_mode,
      'quoted_price_amount', s.quoted_price_amount,
      'final_price_amount', s.final_price_amount,
      'created_at', s.created_at
    ) ORDER BY s.created_at ASC
  ) INTO v_result
  FROM public.shipments s
  JOIN public.parcels p ON p.shipment_id = s.id
  JOIN public.parcel_size_tiers pst ON pst.id = p.sender_declared_size_id
  WHERE s.current_status IN ('REQUESTED', 'PICKUP_IN_PROGRESS')
    AND (
      v_personnel.operating_hub_id IS NULL
      OR s.origin_hub_id = v_personnel.operating_hub_id
      OR s.origin_city ILIKE (SELECT name FROM public.cities WHERE id = (SELECT city_id FROM public.operating_hubs WHERE id = v_personnel.operating_hub_id))
    );

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 3: START PICKUP TASK RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.start_pickup_task(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status NOT IN ('REQUESTED', 'PICKUP_IN_PROGRESS') THEN
    RAISE EXCEPTION 'Cannot start pickup for shipment in state: %', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  UPDATE public.shipments
  SET current_status = 'PICKUP_IN_PROGRESS'
  WHERE id = p_shipment_id;

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
    'PICKUP_STARTED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object('personnel_name', v_personnel.full_name)
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', p_shipment_id,
    'status', 'PICKUP_IN_PROGRESS'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: RECORD RECEIVER VERIFICATION RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.record_receiver_verification(
  p_shipment_id UUID,
  p_outcome TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_verification_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF UPPER(TRIM(p_outcome)) NOT IN (
    'VERIFIED', 'NO_ANSWER', 'INVALID_NUMBER',
    'UNAWARE_OR_DISPUTED', 'DETAILS_NEED_CORRECTION'
  ) THEN
    RAISE EXCEPTION 'Invalid verification outcome: %', p_outcome USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.receiver_verifications (
    shipment_id,
    personnel_id,
    outcome,
    notes
  )
  VALUES (
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_outcome)),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_verification_id;

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
    CASE WHEN UPPER(TRIM(p_outcome)) = 'VERIFIED' THEN 'RECEIVER_VERIFIED' ELSE 'RECEIVER_VERIFICATION_ATTEMPTED' END,
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'outcome', UPPER(TRIM(p_outcome)),
      'notes', p_notes
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'verification_id', v_verification_id,
    'outcome', UPPER(TRIM(p_outcome)),
    'is_verified', (UPPER(TRIM(p_outcome)) = 'VERIFIED')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 5: PARCEL SIZE VERIFICATION & PRICE RECALCULATION RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.verify_and_correct_parcel_size(
  p_shipment_id UUID,
  p_size_tier_code TEXT,
  p_reason TEXT DEFAULT NULL,
  p_sender_acknowledged BOOLEAN DEFAULT TRUE
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
  v_new_tier RECORD;
  v_original_tier RECORD;
  v_new_price INT;
  v_orig_price INT;
  v_sender_obligation INT;
  v_receiver_obligation INT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status NOT IN ('REQUESTED', 'PICKUP_IN_PROGRESS') THEN
    RAISE EXCEPTION 'Cannot adjust parcel size after confirmation.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;
  SELECT * INTO v_original_tier FROM public.parcel_size_tiers WHERE id = v_parcel.sender_declared_size_id;

  SELECT * INTO v_new_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_size_tier_code)) AND is_active = TRUE;

  IF v_new_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_size_tier_code USING ERRCODE = 'P0002';
  END IF;

  -- Recompute authoritative price
  SELECT base_price_amount INTO v_new_price
  FROM public.pricing_rules
  WHERE corridor_id = v_shipment.corridor_id
    AND parcel_size_tier_id = v_new_tier.id
    AND is_active = TRUE;

  IF v_new_price IS NULL THEN
    RAISE EXCEPTION 'No pricing rule found for verified size tier.' USING ERRCODE = 'P0002';
  END IF;

  v_orig_price := v_shipment.quoted_price_amount;

  -- If size changed, record correction and adjust obligations
  IF v_new_tier.id != v_original_tier.id THEN
    INSERT INTO public.parcel_size_corrections (
      shipment_id,
      parcel_id,
      personnel_id,
      original_size_id,
      corrected_size_id,
      original_price_amount,
      corrected_price_amount,
      reason,
      sender_acknowledged
    )
    VALUES (
      p_shipment_id,
      v_parcel.id,
      v_personnel.id,
      v_original_tier.id,
      v_new_tier.id,
      v_orig_price,
      v_new_price,
      p_reason,
      p_sender_acknowledged
    );

    -- Update final price on shipment
    UPDATE public.shipments
    SET final_price_amount = v_new_price
    WHERE id = p_shipment_id;

    -- Adjust Payment Obligations
    IF v_shipment.payment_mode = 'SENDER_PAYS' THEN
      UPDATE public.payment_obligations
      SET expected_amount = v_new_price
      WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';
    ELSIF v_shipment.payment_mode = 'RECEIVER_PAYS' THEN
      UPDATE public.payment_obligations
      SET expected_amount = v_new_price
      WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';
    ELSIF v_shipment.payment_mode = 'SPLIT_PAYMENT' THEN
      -- For split payment, maintain sender's agreed portion if valid, remainder to receiver
      SELECT expected_amount INTO v_sender_obligation
      FROM public.payment_obligations
      WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';

      IF v_sender_obligation >= v_new_price THEN
        v_sender_obligation := v_new_price / 2;
      END IF;
      v_receiver_obligation := v_new_price - v_sender_obligation;

      UPDATE public.payment_obligations
      SET expected_amount = v_sender_obligation
      WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';

      UPDATE public.payment_obligations
      SET expected_amount = v_receiver_obligation
      WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';
    END IF;

    -- Record operational events
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
      'PARCEL_SIZE_CORRECTED',
      v_personnel.id,
      'PERSONNEL',
      v_personnel.operating_hub_id,
      jsonb_build_object(
        'original_size', v_original_tier.code,
        'corrected_size', v_new_tier.code,
        'original_price', v_orig_price,
        'corrected_price', v_new_price
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 6: RECORD PHYSICAL PAYMENT RPC
-- =============================================================================

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
  v_obligation RECORD;
  v_collection_id UUID;
  v_existing_collection RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF UPPER(TRIM(p_payer_party)) NOT IN ('SENDER', 'RECEIVER') THEN
    RAISE EXCEPTION 'Invalid payer party: %', p_payer_party USING ERRCODE = '23514';
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_collection
    FROM public.payment_collections
    WHERE idempotency_key = TRIM(p_idempotency_key);

    IF v_existing_collection IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'collection_id', v_existing_collection.id,
        'amount_collected', v_existing_collection.amount_collected,
        'is_duplicate', true
      );
    END IF;
  END IF;

  SELECT * INTO v_obligation
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id
    AND payer_party = UPPER(TRIM(p_payer_party));

  IF v_obligation IS NULL THEN
    RAISE EXCEPTION 'No payment obligation found for % on this shipment.', p_payer_party USING ERRCODE = 'P0002';
  END IF;

  IF v_obligation.status = 'COLLECTED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Payment already collected.',
      'already_collected', true
    );
  END IF;

  IF p_amount <= 0 OR p_amount != v_obligation.expected_amount THEN
    RAISE EXCEPTION 'Submitted payment amount (%) does not match expected obligation (%).', p_amount, v_obligation.expected_amount
      USING ERRCODE = '23514';
  END IF;

  -- Insert collection record
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
    UPPER(TRIM(p_method)),
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_collection_id;

  -- Update obligation status
  UPDATE public.payment_obligations
  SET status = 'COLLECTED',
      collected_at = NOW(),
      collection_method = UPPER(TRIM(p_method)),
      collected_by_personnel_id = v_personnel.id
  WHERE id = v_obligation.id;

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
    'SHIPMENT',
    p_shipment_id,
    CASE WHEN UPPER(TRIM(p_payer_party)) = 'SENDER' THEN 'SENDER_PAYMENT_COLLECTED' ELSE 'RECEIVER_PAYMENT_COLLECTED' END,
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'amount', p_amount,
      'payer_party', UPPER(TRIM(p_payer_party)),
      'method', UPPER(TRIM(p_method))
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'collection_id', v_collection_id,
    'amount_collected', p_amount,
    'status', 'COLLECTED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 7: ATOMIC CONFIRM PARCEL RPC (CUSTODY TRANSFER & DELIVERY CODE ACTIVATION)
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
  v_sender_obligation RECORD;
  v_delivery_code TEXT;
BEGIN
  -- 1. Must be active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Shipment exists and is in valid state
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Idempotent check: if already confirmed, return existing result
  IF v_shipment.current_status = 'PARCEL_CONFIRMED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'shipment_id', v_shipment.id,
      'delivery_code', v_shipment.delivery_code,
      'status', 'PARCEL_CONFIRMED',
      'already_confirmed', true
    );
  END IF;

  IF v_shipment.current_status NOT IN ('REQUESTED', 'PICKUP_IN_PROGRESS') THEN
    RAISE EXCEPTION 'Shipment is not in pickup state (current: %)', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  -- 3. Verify Receiver Call was successfully completed (MANDATORY)
  SELECT * INTO v_latest_verification
  FROM public.receiver_verifications
  WHERE shipment_id = p_shipment_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_latest_verification IS NULL OR v_latest_verification.outcome != 'VERIFIED' THEN
    RAISE EXCEPTION 'Receiver verification call is mandatory before Confirm Parcel.' USING ERRCODE = '23514';
  END IF;

  -- 4. Verify required Sender payment has been collected
  SELECT * INTO v_sender_obligation
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';

  IF v_sender_obligation IS NOT NULL AND v_sender_obligation.expected_amount > 0 AND v_sender_obligation.status != 'COLLECTED' THEN
    RAISE EXCEPTION 'Required sender payment of % kobo must be collected before Confirm Parcel.', v_sender_obligation.expected_amount
      USING ERRCODE = '23514';
  END IF;

  -- 5. Resolve Verified Size Tier
  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_verified_size_code)) AND is_active = TRUE;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid verified size tier: %', p_verified_size_code USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;

  -- 6. Generate Delivery Code (Server-Authoritative)
  v_delivery_code := public.generate_delivery_code_for_shipment(p_shipment_id);

  -- 7. Atomic Custody Transfer & State Updates
  UPDATE public.parcels
  SET confirmed_size_id = v_tier.id,
      current_parcel_state = 'IN_CERELO_CUSTODY',
      current_custody_type = 'PERSONNEL',
      custody_holder_id = v_personnel.id
  WHERE id = v_parcel.id;

  UPDATE public.shipments
  SET current_status = 'PARCEL_CONFIRMED',
      delivered_by_personnel_id = NULL -- final mile personnel assigned later
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 8: RECORD PICKUP EXCEPTION RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.record_pickup_exception(
  p_shipment_id UUID,
  p_reason TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_exception_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  IF UPPER(TRIM(p_reason)) NOT IN (
    'SENDER_UNAVAILABLE', 'UNACCEPTABLE_PARCEL',
    'PRICE_REJECTED', 'RECEIVER_VERIFICATION_FAILED',
    'PAYMENT_REFUSED', 'OTHER'
  ) THEN
    RAISE EXCEPTION 'Invalid exception reason: %', p_reason USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.pickup_exceptions (
    shipment_id,
    personnel_id,
    reason,
    notes
  )
  VALUES (
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_reason)),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_exception_id;

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
    'PICKUP_FAILED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'reason', UPPER(TRIM(p_reason)),
      'notes', p_notes
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'exception_id', v_exception_id,
    'reason', UPPER(TRIM(p_reason))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_personnel_pickup_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_pickup_task(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_receiver_verification(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_correct_parcel_size(UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_physical_payment(UUID, TEXT, INT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_parcel_pickup(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_pickup_exception(UUID, TEXT, TEXT) TO authenticated;
