-- =============================================================================
-- Cerelo V1 — Personnel Auth, Home-Hub Scope, Atomic Task Claiming & Security Hardening
-- Version: 20260817000020
-- Description:
--   1. Enforces mandatory operating_hub_id on active personnel (no null-hub global access).
--   2. Adds atomic pickup task claiming, assignment ownership, and concurrency locking.
--   3. Adds atomic final-mile delivery task claiming and ownership enforcement.
--   4. Adds admin pickup release and reassignment RPC.
--   5. Hardens customer PII access via scoped RLS and projections.
--   6. Provides get_current_personnel_profile RPC for dynamic client authorization and profile.
-- =============================================================================

-- =============================================================================
-- SECTION 1: SCHEMA ALTERATIONS & CONSTRAINTS
-- =============================================================================

-- Invariant 1: Active Personnel MUST have an assigned operating hub.
-- Inactive / pre-provisioned records may temporarily have NULL until assigned.
ALTER TABLE public.personnel
  DROP CONSTRAINT IF EXISTS chk_personnel_active_hub_required;

ALTER TABLE public.personnel
  ADD CONSTRAINT chk_personnel_active_hub_required
  CHECK (is_active = FALSE OR operating_hub_id IS NOT NULL);

-- Invariant 2: Explicit Task Assignment Tracking on shipments
ALTER TABLE public.shipments
  ADD COLUMN IF NOT EXISTS assigned_pickup_personnel_id UUID REFERENCES public.personnel(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assigned_pickup_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS assigned_delivery_personnel_id UUID REFERENCES public.personnel(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS assigned_delivery_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_shipments_pickup_personnel
  ON public.shipments(assigned_pickup_personnel_id)
  WHERE assigned_pickup_personnel_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shipments_delivery_personnel
  ON public.shipments(assigned_delivery_personnel_id)
  WHERE assigned_delivery_personnel_id IS NOT NULL;

-- =============================================================================
-- SECTION 2: DYNAMIC PERSONNEL PROFILE & AUTHORIZATION RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_current_personnel_profile()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_hub RECORD;
  v_city RECORD;
  v_email TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'is_authorized', false,
      'reason', 'UNAUTHENTICATED'
    );
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id;

  IF v_personnel IS NULL THEN
    RETURN jsonb_build_object(
      'is_authorized', false,
      'user_id', v_user_id,
      'email', v_email,
      'reason', 'NOT_A_PERSONNEL_ACCOUNT'
    );
  END IF;

  IF v_personnel.is_active = FALSE THEN
    RETURN jsonb_build_object(
      'is_authorized', false,
      'user_id', v_user_id,
      'email', v_email,
      'full_name', v_personnel.full_name,
      'reason', 'ACCOUNT_INACTIVE'
    );
  END IF;

  IF v_personnel.operating_hub_id IS NULL THEN
    RETURN jsonb_build_object(
      'is_authorized', false,
      'user_id', v_user_id,
      'email', v_email,
      'full_name', v_personnel.full_name,
      'reason', 'NO_OPERATING_HUB_ASSIGNED'
    );
  END IF;

  SELECT h.*, c.name AS city_name
  INTO v_hub
  FROM public.operating_hubs h
  JOIN public.cities c ON c.id = h.city_id
  WHERE h.id = v_personnel.operating_hub_id;

  RETURN jsonb_build_object(
    'is_authorized', true,
    'personnel_id', v_personnel.id,
    'user_id', v_personnel.user_id,
    'full_name', v_personnel.full_name,
    'phone_number', v_personnel.phone_number,
    'employee_reference', v_personnel.employee_reference,
    'operating_hub_id', v_personnel.operating_hub_id,
    'hub_code', v_hub.code,
    'hub_name', v_hub.name,
    'city_id', v_hub.city_id,
    'city_name', v_hub.city_name,
    'email', v_email,
    'is_active', v_personnel.is_active
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

GRANT EXECUTE ON FUNCTION public.get_current_personnel_profile() TO authenticated;

-- =============================================================================
-- SECTION 3: HARDENED PICKUP QUEUE & ATOMIC CLAIMING
-- =============================================================================

-- 1. Scoped Pickup Queue (Strict Home-Hub Scope, no null-hub fallback)
CREATE OR REPLACE FUNCTION public.get_personnel_pickup_queue()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  -- Select shipments originating at caller's hub that are:
  -- (a) REQUESTED (unclaimed and available to claim) OR
  -- (b) PICKUP_IN_PROGRESS claimed by the calling personnel
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', s.id,
      'delivery_code', s.delivery_code,
      'current_status', s.current_status,
      'origin_city', s.origin_city,
      'destination_city', s.destination_city,
      'origin_hub_id', s.origin_hub_id,
      'destination_hub_id', s.destination_hub_id,
      'assigned_pickup_personnel_id', s.assigned_pickup_personnel_id,
      'is_claimed_by_me', (s.assigned_pickup_personnel_id = v_personnel.id),
      'is_available', (s.assigned_pickup_personnel_id IS NULL AND s.current_status = 'REQUESTED'),
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
    ) ORDER BY
        CASE WHEN s.assigned_pickup_personnel_id = v_personnel.id THEN 0 ELSE 1 END,
        s.created_at ASC
  ) INTO v_result
  FROM public.shipments s
  JOIN public.parcels p ON p.shipment_id = s.id
  JOIN public.parcel_size_tiers pst ON pst.id = p.sender_declared_size_id
  WHERE s.origin_hub_id = v_personnel.operating_hub_id
    AND (
      (s.current_status = 'REQUESTED' AND s.assigned_pickup_personnel_id IS NULL)
      OR (s.current_status = 'PICKUP_IN_PROGRESS' AND s.assigned_pickup_personnel_id = v_personnel.id)
    );

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 2. Atomic Accept/Claim Pickup Task RPC (Concurrency Safe with FOR UPDATE)
CREATE OR REPLACE FUNCTION public.claim_pickup_task(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
BEGIN
  -- Security: Caller must be active personnel with home hub
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  -- Lock shipment row for update to eliminate race conditions
  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Hub Scope Invariant: Must originate at caller's operating hub
  IF v_shipment.origin_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Forbidden: Shipment origin does not match your assigned operating hub.' USING ERRCODE = '42501';
  END IF;

  -- Idempotency check: If already claimed by caller
  IF v_shipment.assigned_pickup_personnel_id = v_personnel.id AND v_shipment.current_status = 'PICKUP_IN_PROGRESS' THEN
    RETURN jsonb_build_object(
      'success', true,
      'shipment_id', p_shipment_id,
      'status', 'PICKUP_IN_PROGRESS',
      'assigned_to_me', true,
      'already_claimed_by_you', true
    );
  END IF;

  -- Concurrency check: If claimed by someone else
  IF v_shipment.assigned_pickup_personnel_id IS NOT NULL AND v_shipment.assigned_pickup_personnel_id != v_personnel.id THEN
    RAISE EXCEPTION 'This pickup has already been accepted by another Personnel member.' USING ERRCODE = '23514';
  END IF;

  -- State check: Must be REQUESTED
  IF v_shipment.current_status != 'REQUESTED' THEN
    RAISE EXCEPTION 'Cannot claim shipment in current state: %', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  -- Atomic claim mutation
  UPDATE public.shipments
  SET current_status = 'PICKUP_IN_PROGRESS',
      assigned_pickup_personnel_id = v_personnel.id,
      assigned_pickup_at = NOW()
  WHERE id = p_shipment_id;

  -- Record audit event
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
    'PICKUP_CLAIMED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'personnel_id', v_personnel.id,
      'personnel_name', v_personnel.full_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', p_shipment_id,
    'status', 'PICKUP_IN_PROGRESS',
    'assigned_to_me', true,
    'already_claimed_by_you', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- Backward compatible alias for start_pickup_task
CREATE OR REPLACE FUNCTION public.start_pickup_task(p_shipment_id UUID)
RETURNS JSONB AS $$
BEGIN
  RETURN public.claim_pickup_task(p_shipment_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 3. Hardened Receiver Verification RPC (Owner-Enforced)
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
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Owner check: Must be assigned to caller
  IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned pickup personnel for this shipment.' USING ERRCODE = '42501';
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 4. Hardened Parcel Size Verification RPC (Owner-Enforced)
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
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Owner check
  IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned pickup personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'PICKUP_IN_PROGRESS' THEN
    RAISE EXCEPTION 'Cannot adjust parcel size after confirmation (current: %)', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;
  SELECT * INTO v_original_tier FROM public.parcel_size_tiers WHERE id = v_parcel.sender_declared_size_id;

  SELECT * INTO v_new_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_size_tier_code)) AND is_active = TRUE;

  IF v_new_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_size_tier_code USING ERRCODE = 'P0002';
  END IF;

  -- Authoritative price calculation
  SELECT base_price_amount INTO v_new_price
  FROM public.pricing_rules
  WHERE corridor_id = v_shipment.corridor_id
    AND parcel_size_tier_id = v_new_tier.id
    AND is_active = TRUE;

  IF v_new_price IS NULL THEN
    RAISE EXCEPTION 'No pricing rule found for verified size tier.' USING ERRCODE = 'P0002';
  END IF;

  v_orig_price := v_shipment.quoted_price_amount;

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

    UPDATE public.shipments
    SET final_price_amount = v_new_price
    WHERE id = p_shipment_id;

    -- Adjust Obligations
    IF v_shipment.payment_mode = 'SENDER_PAYS' THEN
      UPDATE public.payment_obligations
      SET expected_amount = v_new_price
      WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';
    ELSIF v_shipment.payment_mode = 'RECEIVER_PAYS' THEN
      UPDATE public.payment_obligations
      SET expected_amount = v_new_price
      WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';
    ELSIF v_shipment.payment_mode = 'SPLIT_PAYMENT' THEN
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 5. Hardened Record Physical Payment RPC (Owner & Cash Enforced)
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
  v_collection_id UUID;
  v_existing_collection RECORD;
BEGIN
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  IF UPPER(TRIM(p_payer_party)) NOT IN ('SENDER', 'RECEIVER') THEN
    RAISE EXCEPTION 'Invalid payer party: %', p_payer_party USING ERRCODE = '23514';
  END IF;

  -- CASH-only operational invariant
  IF UPPER(TRIM(p_method)) != 'CASH' THEN
    RAISE EXCEPTION 'Only physical CASH collection is supported in V1 (submitted: %).', p_method USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Ownership verification
  IF UPPER(TRIM(p_payer_party)) = 'SENDER' THEN
    IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
      RAISE EXCEPTION 'Forbidden: You are not the assigned pickup personnel for this shipment.' USING ERRCODE = '42501';
    END IF;
  ELSIF UPPER(TRIM(p_payer_party)) = 'RECEIVER' THEN
    IF v_shipment.assigned_delivery_personnel_id IS DISTINCT FROM v_personnel.id THEN
      RAISE EXCEPTION 'Forbidden: You are not the assigned delivery personnel for this shipment.' USING ERRCODE = '42501';
    END IF;
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
    'CASH',
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_collection_id;

  UPDATE public.payment_obligations
  SET status = 'COLLECTED',
      collected_at = NOW(),
      collection_method = 'CASH',
      collected_by_personnel_id = v_personnel.id
  WHERE id = v_obligation.id;

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
      'method', 'CASH'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'collection_id', v_collection_id,
    'amount_collected', p_amount,
    'status', 'COLLECTED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 6. Hardened Confirm Parcel Pickup RPC (Owner-Enforced)
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

  -- 4. Verify Sender Payment
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

-- 7. Admin Reassign / Release Pickup Task RPC
CREATE OR REPLACE FUNCTION public.admin_reassign_pickup_task(
  p_shipment_id UUID,
  p_new_personnel_id UUID,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_shipment RECORD;
  v_new_personnel RECORD;
  v_old_personnel_id UUID;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RAISE EXCEPTION 'Reason required for pickup reassignment.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status NOT IN ('REQUESTED', 'PICKUP_IN_PROGRESS') THEN
    RAISE EXCEPTION 'Cannot reassign shipment in status %', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  v_old_personnel_id := v_shipment.assigned_pickup_personnel_id;

  IF p_new_personnel_id IS NOT NULL THEN
    SELECT * INTO v_new_personnel
    FROM public.personnel
    WHERE id = p_new_personnel_id AND is_active = TRUE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Target personnel not found or inactive.' USING ERRCODE = 'P0002';
    END IF;

    IF v_new_personnel.operating_hub_id != v_shipment.origin_hub_id THEN
      RAISE EXCEPTION 'Target personnel is assigned to a different hub.' USING ERRCODE = '23514';
    END IF;

    UPDATE public.shipments
    SET assigned_pickup_personnel_id = p_new_personnel_id,
        assigned_pickup_at = NOW(),
        current_status = 'PICKUP_IN_PROGRESS'
    WHERE id = p_shipment_id;
  ELSE
    -- Release back to pool
    UPDATE public.shipments
    SET assigned_pickup_personnel_id = NULL,
        assigned_pickup_at = NULL,
        current_status = 'REQUESTED'
    WHERE id = p_shipment_id;
  END IF;

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
    'REASSIGN_PICKUP_TASK',
    'SHIPMENT',
    p_shipment_id,
    TRIM(p_reason),
    jsonb_build_object('assigned_pickup_personnel_id', v_old_personnel_id),
    jsonb_build_object('assigned_pickup_personnel_id', p_new_personnel_id)
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
    'ADMIN_PICKUP_REASSIGNED',
    v_admin.id,
    'ADMIN',
    v_shipment.origin_hub_id,
    jsonb_build_object(
      'from_personnel_id', v_old_personnel_id,
      'to_personnel_id', p_new_personnel_id,
      'reason', p_reason
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', p_shipment_id,
    'assigned_pickup_personnel_id', p_new_personnel_id,
    'status', CASE WHEN p_new_personnel_id IS NULL THEN 'REQUESTED' ELSE 'PICKUP_IN_PROGRESS' END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

GRANT EXECUTE ON FUNCTION public.admin_reassign_pickup_task(UUID, UUID, TEXT) TO authenticated;

-- =============================================================================
-- SECTION 4: HARDENED FINAL-MILE DELIVERY QUEUE & ATOMIC CLAIMING
-- =============================================================================

-- 1. Scoped Destination Delivery Queue (Strict Home-Hub Scope)
CREATE OR REPLACE FUNCTION public.get_ready_for_delivery_queue()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
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
      'origin_hub_id', s.origin_hub_id,
      'destination_hub_id', s.destination_hub_id,
      'assigned_delivery_personnel_id', s.assigned_delivery_personnel_id,
      'is_claimed_by_me', (s.assigned_delivery_personnel_id = v_personnel.id),
      'is_available', (s.assigned_delivery_personnel_id IS NULL AND s.current_status = 'ARRIVED_DESTINATION'),
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
    ) ORDER BY
        CASE WHEN s.assigned_delivery_personnel_id = v_personnel.id THEN 0 ELSE 1 END,
        s.created_at ASC
  ) INTO v_result
  FROM public.shipments s
  JOIN public.parcels p ON p.shipment_id = s.id
  JOIN public.parcel_size_tiers pst ON pst.id = COALESCE(p.confirmed_size_id, p.sender_declared_size_id)
  LEFT JOIN public.payment_obligations po ON po.shipment_id = s.id AND po.payer_party = 'RECEIVER'
  WHERE s.destination_hub_id = v_personnel.operating_hub_id
    AND (
      (s.current_status = 'ARRIVED_DESTINATION' AND s.assigned_delivery_personnel_id IS NULL)
      OR (s.current_status = 'OUT_FOR_DELIVERY' AND s.assigned_delivery_personnel_id = v_personnel.id)
    );

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 2. Atomic Final Delivery Claiming RPC (Concurrency Safe with FOR UPDATE)
CREATE OR REPLACE FUNCTION public.start_final_delivery(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
BEGIN
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Hub Scope Invariant: Must deliver to caller's operating hub
  IF v_shipment.destination_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Forbidden: Shipment destination does not match your assigned operating hub.' USING ERRCODE = '42501';
  END IF;

  -- Idempotency check: Already claimed by caller
  IF v_shipment.assigned_delivery_personnel_id = v_personnel.id AND v_shipment.current_status = 'OUT_FOR_DELIVERY' THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', 'OUT_FOR_DELIVERY',
      'assigned_to_me', true,
      'already_started', true
    );
  END IF;

  -- Concurrency check: Claimed by someone else
  IF v_shipment.assigned_delivery_personnel_id IS NOT NULL AND v_shipment.assigned_delivery_personnel_id != v_personnel.id THEN
    RAISE EXCEPTION 'This delivery has already been claimed by another Personnel member.' USING ERRCODE = '23514';
  END IF;

  IF v_shipment.current_status != 'ARRIVED_DESTINATION' THEN
    RAISE EXCEPTION 'Shipment is not ready for final delivery (current status: %)', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;

  UPDATE public.shipments
  SET current_status = 'OUT_FOR_DELIVERY',
      assigned_delivery_personnel_id = v_personnel.id,
      assigned_delivery_at = NOW()
  WHERE id = p_shipment_id;

  UPDATE public.parcels
  SET current_parcel_state = 'FINAL_DELIVERY_STAGED',
      current_custody_type = 'PERSONNEL',
      custody_holder_id = v_personnel.id
  WHERE id = v_parcel.id;

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
    'SHIPMENT_OUT_FOR_DELIVERY',
    v_personnel.id,
    'PERSONNEL',
    v_shipment.destination_hub_id,
    jsonb_build_object(
      'status', 'OUT_FOR_DELIVERY',
      'personnel_id', v_personnel.id,
      'personnel_name', v_personnel.full_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'OUT_FOR_DELIVERY',
    'assigned_to_me', true,
    'already_started', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 3. Hardened Mark Delivered RPC (Owner-Enforced)
CREATE OR REPLACE FUNCTION public.mark_delivered(
  p_shipment_id     UUID,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id          UUID := auth.uid();
  v_personnel        RECORD;
  v_shipment         RECORD;
  v_parcel           RECORD;
  v_receiver_amount  INT;
BEGIN
  SET LOCAL row_security = off;

  -- 1. Security: active Personnel identity
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF NOT FOUND OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate shipment & lock
  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Idempotent: already delivered
  IF v_shipment.current_status = 'DELIVERED' THEN
    RETURN jsonb_build_object(
      'success',          true,
      'status',           'DELIVERED',
      'already_delivered', true,
      'message',          'Shipment is already delivered.'
    );
  END IF;

  -- Owner check: Must be assigned to caller
  IF v_shipment.assigned_delivery_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned delivery personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'OUT_FOR_DELIVERY' THEN
    RAISE EXCEPTION
      'Shipment must be OUT_FOR_DELIVERY before it can be marked DELIVERED (current: %)',
      v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  -- 3. Payment precondition: RECEIVER obligation must be COLLECTED
  SELECT expected_amount INTO v_receiver_amount
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id
    AND payer_party  = 'RECEIVER'
    AND expected_amount > 0;

  IF FOUND AND v_receiver_amount > 0 THEN
    PERFORM FROM public.payment_obligations
    WHERE shipment_id   = p_shipment_id
      AND payer_party   = 'RECEIVER'
      AND expected_amount > 0
      AND status        = 'COLLECTED';

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'Cannot mark delivered: Outstanding receiver payment of ₦% has not been collected.',
        (v_receiver_amount / 100)
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- 4. Lock parcel
  SELECT * INTO v_parcel
  FROM public.parcels
  WHERE shipment_id = p_shipment_id
  FOR UPDATE;

  -- 5. Atomic delivery completion
  UPDATE public.shipments
  SET current_status          = 'DELIVERED',
      delivered_at            = NOW(),
      delivered_by_personnel_id = v_personnel.id
  WHERE id = p_shipment_id;

  UPDATE public.parcels
  SET current_parcel_state    = 'HANDED_OVER',
      current_custody_type    = 'RECEIVER',
      custody_holder_id       = NULL
  WHERE id = v_parcel.id;

  -- 6. Record delivery attempt
  INSERT INTO public.delivery_attempts (
    shipment_id, attempted_by_personnel_id, outcome, notes
  ) VALUES (
    p_shipment_id, v_personnel.id, 'DELIVERED',
    'Parcel physically handed over to receiver by authorized personnel.'
  );

  -- 7. Immutable audit events
  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type,
    actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'SHIPMENT', p_shipment_id, 'SHIPMENT_DELIVERED',
    v_personnel.id, 'PERSONNEL', v_shipment.destination_hub_id,
    jsonb_build_object(
      'status',        'DELIVERED',
      'delivered_by',  v_personnel.full_name,
      'delivery_code', v_shipment.delivery_code
    )
  );

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type,
    actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'PARCEL', v_parcel.id, 'CUSTODY_TRANSFERRED',
    v_personnel.id, 'PERSONNEL', v_shipment.destination_hub_id,
    jsonb_build_object('from_custody', 'PERSONNEL', 'to_custody', 'RECEIVER')
  );

  RETURN jsonb_build_object(
    'success',          true,
    'status',           'DELIVERED',
    'already_delivered', false,
    'delivery_code',    v_shipment.delivery_code
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- Companion overload
CREATE OR REPLACE FUNCTION public.mark_delivered(
  p_shipment_id     UUID,
  p_delivery_code   TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  RETURN public.mark_delivered(p_shipment_id, p_idempotency_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 4. Hardened Sender Completion Call RPC (Owner-Enforced)
CREATE OR REPLACE FUNCTION public.record_sender_completion_call(
  p_shipment_id UUID,
  p_outcome TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF v_personnel IS NULL OR v_personnel.operating_hub_id IS NULL THEN
    RAISE EXCEPTION 'Active personnel access with assigned operating hub required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Owner check: Must be delivered by caller
  IF v_shipment.delivered_by_personnel_id IS DISTINCT FROM v_personnel.id AND v_shipment.assigned_delivery_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the delivery personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.shipments
  SET sender_completion_call_outcome = UPPER(p_outcome),
      sender_completion_call_at = NOW()
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
    'SENDER_COMPLETION_CALL_RECORDED',
    v_personnel.id,
    'PERSONNEL',
    v_shipment.destination_hub_id,
    jsonb_build_object('outcome', UPPER(p_outcome), 'notes', p_notes)
  );

  RETURN jsonb_build_object('success', true, 'outcome', UPPER(p_outcome));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 5: CUSTOMER PII LEAST-PRIVILEGE RLS HARDENING
-- =============================================================================

-- Drop broad "personnel: read customers for operations" policy
DROP POLICY IF EXISTS "personnel: read customers for operations" ON public.customers;

-- Replace with scoped policy: Personnel can only select customer rows associated
-- with shipments inside their assigned operating hub scope.
CREATE POLICY "personnel: scoped customer read for hub tasks"
  ON public.customers FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.personnel p
      JOIN public.shipments s ON (s.origin_hub_id = p.operating_hub_id OR s.destination_hub_id = p.operating_hub_id)
      WHERE p.user_id = auth.uid()
        AND p.is_active = TRUE
        AND p.operating_hub_id IS NOT NULL
        AND (s.sender_customer_id = public.customers.id OR s.receiver_customer_id = public.customers.id)
    )
  );

-- =============================================================================
-- SECTION 6: GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.claim_pickup_task(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_pickup_task(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_personnel_pickup_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ready_for_delivery_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_final_delivery(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_sender_completion_call(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_and_correct_parcel_size(UUID, TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_receiver_verification(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_physical_payment(UUID, TEXT, INT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_parcel_pickup(UUID, TEXT, TEXT) TO authenticated;
