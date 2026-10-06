-- =============================================================================
-- Cerelo V1 — Share Tokens, Delivery Code & Receiver Linking Migration
-- Version: 20260817000004
-- Description: Share tokens entity, Delivery Code generation domain service,
--              secure token resolution, and server-authoritative Receiver account linking.
-- =============================================================================

-- =============================================================================
-- SECTION 1: DELIVERY CODE NULLABLE ON INITIAL REQUEST
-- =============================================================================

ALTER TABLE public.shipments ALTER COLUMN delivery_code DROP NOT NULL;

-- Update create_shipment_request to not generate delivery_code at request time
CREATE OR REPLACE FUNCTION public.create_shipment_request(
  p_origin_city TEXT,
  p_destination_city TEXT,
  p_sender_pickup_address TEXT,
  p_receiver_name TEXT,
  p_receiver_phone TEXT,
  p_receiver_delivery_address TEXT,
  p_parcel_size_code TEXT,
  p_category_description TEXT,
  p_payment_mode TEXT,
  p_sender_payment_amount INT DEFAULT NULL,
  p_delivery_instructions TEXT DEFAULT NULL,
  p_landmark TEXT DEFAULT NULL,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_customer RECORD;
  v_corridor RECORD;
  v_tier RECORD;
  v_price INT;
  v_currency TEXT;
  v_shipment_id UUID;
  v_parcel_id UUID;
  v_sender_obligation INT;
  v_receiver_obligation INT;
  v_normalized_receiver_phone TEXT;
  v_existing_shipment RECORD;
BEGIN
  -- 1. Security check: caller must be authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Verify customer is active and onboarding is complete
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_customer.onboarding_completed_at IS NULL THEN
    RAISE EXCEPTION 'Customer onboarding must be completed before requesting shipments.'
      USING ERRCODE = '23514';
  END IF;

  -- 3. Check idempotency: if same key exists for this user, return existing record
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_shipment
    FROM public.shipments
    WHERE idempotency_key = TRIM(p_idempotency_key)
      AND sender_customer_id = v_user_id;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'id', v_existing_shipment.id,
        'delivery_code', v_existing_shipment.delivery_code,
        'current_status', v_existing_shipment.current_status,
        'origin_city', v_existing_shipment.origin_city,
        'destination_city', v_existing_shipment.destination_city,
        'quoted_price_amount', v_existing_shipment.quoted_price_amount,
        'final_price_amount', v_existing_shipment.final_price_amount,
        'payment_mode', v_existing_shipment.payment_mode,
        'created_at', v_existing_shipment.created_at,
        'is_duplicate', true
      );
    END IF;
  END IF;

  -- 4. Validate and resolve Corridor
  SELECT c.*, orig.name AS orig_name, dest.name AS dest_name
  INTO v_corridor
  FROM public.corridors c
  JOIN public.cities orig ON orig.id = c.origin_city_id
  JOIN public.cities dest ON dest.id = c.destination_city_id
  WHERE orig.name ILIKE TRIM(p_origin_city)
    AND dest.name ILIKE TRIM(p_destination_city)
    AND c.is_active = TRUE;

  IF v_corridor IS NULL THEN
    RAISE EXCEPTION 'Unsupported corridor: % to %', p_origin_city, p_destination_city
      USING ERRCODE = 'P0002';
  END IF;

  -- 5. Validate and resolve Parcel Size Tier
  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_parcel_size_code))
    AND is_active = TRUE;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_parcel_size_code
      USING ERRCODE = 'P0002';
  END IF;

  -- 6. Authoritative Pricing calculation
  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id = v_corridor.id
    AND parcel_size_tier_id = v_tier.id
    AND is_active = TRUE;

  IF v_price IS NULL THEN
    RAISE EXCEPTION 'No active pricing rule found for route.' USING ERRCODE = 'P0002';
  END IF;

  -- 7. Validate Receiver details
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

  -- 8. Validate Payment Mode & Calculate Obligations
  IF UPPER(TRIM(p_payment_mode)) NOT IN ('SENDER_PAYS', 'RECEIVER_PAYS', 'SPLIT_PAYMENT') THEN
    RAISE EXCEPTION 'Invalid payment mode: %', p_payment_mode USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_payment_mode)) = 'SENDER_PAYS' THEN
    v_sender_obligation := v_price;
    v_receiver_obligation := 0;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'RECEIVER_PAYS' THEN
    v_sender_obligation := 0;
    v_receiver_obligation := v_price;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'SPLIT_PAYMENT' THEN
    IF p_sender_payment_amount IS NULL OR p_sender_payment_amount <= 0 OR p_sender_payment_amount >= v_price THEN
      RAISE EXCEPTION 'For Split Payment, sender amount must be strictly between 0 and total price (%)', v_price
        USING ERRCODE = '23514';
    END IF;
    v_sender_obligation := p_sender_payment_amount;
    v_receiver_obligation := v_price - p_sender_payment_amount;
  END IF;

  -- 9. Atomic Insert: shipments (delivery_code is NULL at request stage)
  INSERT INTO public.shipments (
    delivery_code,
    sender_customer_id,
    corridor_id,
    origin_city,
    destination_city,
    origin_hub_id,
    destination_hub_id,
    sender_name_snapshot,
    sender_phone_snapshot,
    sender_pickup_address_snapshot,
    receiver_name_snapshot,
    receiver_phone_snapshot,
    receiver_delivery_address_snapshot,
    delivery_instructions,
    landmark,
    quoted_price_amount,
    final_price_amount,
    currency,
    payment_mode,
    current_status,
    idempotency_key
  )
  VALUES (
    NULL,
    v_user_id,
    v_corridor.id,
    v_corridor.orig_name,
    v_corridor.dest_name,
    v_corridor.origin_hub_id,
    v_corridor.destination_hub_id,
    v_customer.full_name,
    COALESCE(v_customer.phone_number, ''),
    TRIM(p_sender_pickup_address),
    TRIM(p_receiver_name),
    v_normalized_receiver_phone,
    TRIM(p_receiver_delivery_address),
    NULLIF(TRIM(p_delivery_instructions), ''),
    NULLIF(TRIM(p_landmark), ''),
    v_price,
    v_price,
    v_currency,
    UPPER(TRIM(p_payment_mode)),
    'REQUESTED',
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_shipment_id;

  -- 10. Atomic Insert: parcels (1-to-1)
  INSERT INTO public.parcels (
    shipment_id,
    sender_declared_size_id,
    category_description,
    current_parcel_state,
    current_custody_type
  )
  VALUES (
    v_shipment_id,
    v_tier.id,
    COALESCE(NULLIF(TRIM(p_category_description), ''), 'General Goods'),
    'UNCONFIRMED',
    'SENDER'
  )
  RETURNING id INTO v_parcel_id;

  -- 11. Atomic Insert: payment_obligations
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

  -- 12. Atomic Insert: operational_events (SHIPMENT_REQUESTED)
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
    v_shipment_id,
    'SHIPMENT_REQUESTED',
    v_user_id,
    'CUSTOMER',
    v_corridor.origin_hub_id,
    jsonb_build_object(
      'route', v_corridor.code,
      'payment_mode', UPPER(TRIM(p_payment_mode)),
      'price', v_price
    )
  );

  RETURN jsonb_build_object(
    'id', v_shipment_id,
    'delivery_code', NULL,
    'current_status', 'REQUESTED',
    'origin_city', v_corridor.orig_name,
    'destination_city', v_corridor.dest_name,
    'quoted_price_amount', v_price,
    'final_price_amount', v_price,
    'currency', v_currency,
    'payment_mode', UPPER(TRIM(p_payment_mode)),
    'sender_name_snapshot', v_customer.full_name,
    'receiver_name_snapshot', TRIM(p_receiver_name),
    'created_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 2: SHARE TOKENS ENTITY
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.share_tokens (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id           UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  token                 TEXT NOT NULL UNIQUE,
  created_by_customer_id UUID NOT NULL REFERENCES public.customers(id),
  is_revoked            BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at            TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_share_tokens_lookup ON public.share_tokens(token) WHERE is_revoked = FALSE;
CREATE INDEX IF NOT EXISTS idx_share_tokens_shipment ON public.share_tokens(shipment_id);

ALTER TABLE public.share_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "share_tokens: creator select"
  ON public.share_tokens FOR SELECT
  USING (created_by_customer_id = auth.uid() OR (auth.jwt()->>'role') IN ('personnel', 'admin'));

-- =============================================================================
-- SECTION 3: DELIVERY CODE GENERATION & VERIFICATION RPCS
-- =============================================================================

-- Server-side operational generator (called on Confirm Parcel)
CREATE OR REPLACE FUNCTION public.generate_delivery_code_for_shipment(p_shipment_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_shipment RECORD;
  v_code TEXT;
  v_collision_count INT := 0;
BEGIN
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.delivery_code IS NOT NULL THEN
    RETURN v_shipment.delivery_code;
  END IF;

  LOOP
    v_code := public.generate_delivery_code();
    BEGIN
      UPDATE public.shipments
      SET delivery_code = v_code
      WHERE id = p_shipment_id;
      EXIT; -- Success
    EXCEPTION WHEN unique_violation THEN
      v_collision_count := v_collision_count + 1;
      IF v_collision_count > 10 THEN
        RAISE EXCEPTION 'Failed to generate unique delivery code after multiple attempts.' USING ERRCODE = '23505';
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
    payload
  )
  VALUES (
    'SHIPMENT',
    p_shipment_id,
    'DELIVERY_CODE_GENERATED',
    COALESCE(auth.uid(), v_shipment.sender_customer_id),
    'SYSTEM',
    jsonb_build_object('delivery_code', v_code)
  );

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sender manual Delivery Code verification
CREATE OR REPLACE FUNCTION public.verify_sender_delivery_code(
  p_shipment_id UUID,
  p_delivery_code TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_shipment RECORD;
  v_cleaned_code TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found or access denied.' USING ERRCODE = 'P0002';
  END IF;

  -- Only legitimate Sender can verify
  IF v_shipment.sender_customer_id != v_user_id THEN
    RAISE EXCEPTION 'Only the sender can verify this delivery code.' USING ERRCODE = '42501';
  END IF;

  v_cleaned_code := UPPER(TRIM(p_delivery_code));

  IF v_shipment.delivery_code IS NOT NULL AND v_shipment.delivery_code = v_cleaned_code THEN
    -- Record verification event
    INSERT INTO public.operational_events (
      aggregate_type,
      aggregate_id,
      event_type,
      actor_id,
      actor_role,
      payload
    )
    VALUES (
      'SHIPMENT',
      p_shipment_id,
      'DELIVERY_CODE_VERIFIED_BY_SENDER',
      v_user_id,
      'CUSTOMER',
      jsonb_build_object('delivery_code', v_cleaned_code)
    );

    RETURN jsonb_build_object(
      'is_valid', true,
      'status', v_shipment.current_status,
      'delivery_code', v_cleaned_code
    );
  ELSE
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'INVALID_DELIVERY_CODE'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: SHARE LINK MANAGEMENT RPCS
-- =============================================================================

-- Create or retrieve existing active share link for Sender
CREATE OR REPLACE FUNCTION public.create_or_get_shipment_share_link(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_shipment RECORD;
  v_existing_token RECORD;
  v_raw_token TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id;

  IF v_shipment IS NULL OR (v_shipment.sender_customer_id != v_user_id AND v_shipment.receiver_customer_id != v_user_id) THEN
    RAISE EXCEPTION 'Shipment not found or access denied.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status = 'CANCELLED' THEN
    RAISE EXCEPTION 'Cannot share a cancelled shipment.' USING ERRCODE = '23514';
  END IF;

  -- Check existing active token
  SELECT * INTO v_existing_token
  FROM public.share_tokens
  WHERE shipment_id = p_shipment_id
    AND is_revoked = FALSE
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_existing_token IS NOT NULL THEN
    RETURN jsonb_build_object(
      'token', v_existing_token.token,
      'expires_at', v_existing_token.expires_at,
      'share_url', 'https://cerelo.ng/s/' || v_existing_token.token
    );
  END IF;

  -- Generate 32-character random hex token
  v_raw_token := encode(gen_random_bytes(16), 'hex');
  v_expires_at := NOW() + INTERVAL '30 days';

  INSERT INTO public.share_tokens (
    shipment_id,
    token,
    created_by_customer_id,
    expires_at
  )
  VALUES (
    p_shipment_id,
    v_raw_token,
    v_user_id,
    v_expires_at
  );

  RETURN jsonb_build_object(
    'token', v_raw_token,
    'expires_at', v_expires_at,
    'share_url', 'https://cerelo.ng/s/' || v_raw_token
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke share link
CREATE OR REPLACE FUNCTION public.revoke_shipment_share_link(p_shipment_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_shipment RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL OR v_shipment.sender_customer_id != v_user_id THEN
    RAISE EXCEPTION 'Shipment not found or access denied.' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.share_tokens
  SET is_revoked = TRUE
  WHERE shipment_id = p_shipment_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 5: RESOLVE SHARE TOKEN (Restricted Shared Viewer Projection)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.resolve_shipment_share_token(p_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_share RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
  v_receiver_obligation INT := 0;
  v_user_id UUID := auth.uid();
  v_caller_phone TEXT;
  v_is_intended_receiver BOOLEAN := FALSE;
  v_sender_first_name TEXT;
  v_receiver_masked_phone TEXT;
BEGIN
  IF p_token IS NULL OR TRIM(p_token) = '' THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'INVALID_TOKEN');
  END IF;

  SELECT * INTO v_share
  FROM public.share_tokens
  WHERE token = TRIM(p_token)
    AND is_revoked = FALSE
    AND expires_at > NOW();

  IF v_share IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'INVALID_OR_EXPIRED_TOKEN');
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_share.shipment_id;
  IF v_shipment IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'SHIPMENT_NOT_FOUND');
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = v_shipment.id;

  -- Get receiver obligation amount if applicable
  SELECT expected_amount INTO v_receiver_obligation
  FROM public.payment_obligations
  WHERE shipment_id = v_shipment.id AND payer_party = 'RECEIVER';

  -- Check if caller phone matches receiver phone snapshot
  IF v_user_id IS NOT NULL THEN
    SELECT phone_number INTO v_caller_phone FROM public.customers WHERE id = v_user_id;
    IF v_caller_phone IS NOT NULL AND v_caller_phone != '' AND v_caller_phone = v_shipment.receiver_phone_snapshot THEN
      v_is_intended_receiver := TRUE;
    END IF;
  END IF;

  -- Privacy masking: First name only for Sender
  v_sender_first_name := split_part(v_shipment.sender_name_snapshot, ' ', 1);
  -- Phone masking for receiver: e.g. +234 801 ***5678
  IF length(v_shipment.receiver_phone_snapshot) >= 10 THEN
    v_receiver_masked_phone := substr(v_shipment.receiver_phone_snapshot, 1, 8) || '***' || substr(v_shipment.receiver_phone_snapshot, length(v_shipment.receiver_phone_snapshot) - 3);
  ELSE
    v_receiver_masked_phone := '***';
  END IF;

  RETURN jsonb_build_object(
    'is_valid', true,
    'shipment_id', v_shipment.id,
    'origin_city', v_shipment.origin_city,
    'destination_city', v_shipment.destination_city,
    'current_status', v_shipment.current_status,
    'sender_display_name', v_sender_first_name,
    'receiver_name_snapshot', v_shipment.receiver_name_snapshot,
    'receiver_phone_masked', v_receiver_masked_phone,
    'receiver_delivery_address', v_shipment.receiver_delivery_address_snapshot,
    'category_description', COALESCE(v_parcel.category_description, 'General Package'),
    'payment_mode', v_shipment.payment_mode,
    'receiver_expected_amount', COALESCE(v_receiver_obligation, 0),
    'already_linked', (v_shipment.receiver_customer_id IS NOT NULL),
    'is_intended_receiver', v_is_intended_receiver,
    'created_at', v_shipment.created_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 6: LINK AUTHENTICATED RECEIVER TO SHIPMENT
-- =============================================================================

CREATE OR REPLACE FUNCTION public.link_authenticated_receiver_to_shipment(p_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_customer RECORD;
  v_share RECORD;
  v_shipment RECORD;
BEGIN
  -- 1. Must be authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to claim shipment.' USING ERRCODE = '42501';
  END IF;

  -- 2. Verify customer profile & onboarding
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_customer.onboarding_completed_at IS NULL THEN
    RAISE EXCEPTION 'Please complete onboarding before claiming deliveries.' USING ERRCODE = '23514';
  END IF;

  -- 3. Resolve share token
  SELECT * INTO v_share
  FROM public.share_tokens
  WHERE token = TRIM(p_token)
    AND is_revoked = FALSE
    AND expires_at > NOW();

  IF v_share IS NULL THEN
    RAISE EXCEPTION 'Invalid, revoked, or expired share link.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_share.shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- 4. Check if already linked to caller (Idempotent)
  IF v_shipment.receiver_customer_id = v_user_id THEN
    RETURN jsonb_build_object(
      'success', true,
      'shipment_id', v_shipment.id,
      'already_linked', true,
      'message', 'Shipment is already linked to your account.'
    );
  END IF;

  -- 5. If already linked to a different customer, block takeover
  IF v_shipment.receiver_customer_id IS NOT NULL AND v_shipment.receiver_customer_id != v_user_id THEN
    RAISE EXCEPTION 'This shipment has already been claimed by another receiver.' USING ERRCODE = '23514';
  END IF;

  -- 6. Link Receiver atomically
  UPDATE public.shipments
  SET receiver_customer_id = v_user_id
  WHERE id = v_shipment.id;

  -- 7. Record operational event (RECEIVER_ACCOUNT_LINKED)
  INSERT INTO public.operational_events (
    aggregate_type,
    aggregate_id,
    event_type,
    actor_id,
    actor_role,
    payload
  )
  VALUES (
    'SHIPMENT',
    v_shipment.id,
    'RECEIVER_ACCOUNT_LINKED',
    v_user_id,
    'CUSTOMER',
    jsonb_build_object(
      'receiver_customer_id', v_user_id,
      'receiver_name', v_customer.full_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', v_shipment.id,
    'already_linked', false,
    'message', 'Delivery successfully added to your received parcels.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.generate_delivery_code_for_shipment(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_sender_delivery_code(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_or_get_shipment_share_link(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_shipment_share_link(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_shipment_share_token(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.link_authenticated_receiver_to_shipment(TEXT) TO authenticated;
