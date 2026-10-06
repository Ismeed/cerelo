-- =============================================================================
-- Cerelo V1 — P0.1 Independent Fare Adjustment & Pricing Semantics
-- Version: 20260827000024
-- Description:
--   1. Add pricing audit columns to shipments (fare_adjusted, fare_adjustment_reason,
--      fare_adjusted_by, fare_adjusted_at).
--   2. Implement adjust_pickup_fare RPC:
--      Authoritative independent fare agreement between Personnel and Sender.
--      Allowed only during active pickup before cash collection / confirm.
--      Enforces reason, sender agreement, positive integer kobo, 50/50 split recalculation.
--      Emits single immutable FARE_ADJUSTED event.
--   3. Make verify_and_correct_parcel_size idempotent:
--      Updates parcels.confirmed_size_id and emits PARCEL_SIZE_CORRECTED only
--      when size tier actually changes.
-- =============================================================================

-- =============================================================================
-- SECTION 1: ADD PRICING AUDIT COLUMNS TO SHIPMENTS
-- =============================================================================

ALTER TABLE public.shipments
  ADD COLUMN IF NOT EXISTS fare_adjusted BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS fare_adjustment_reason TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS fare_adjusted_by UUID REFERENCES auth.users(id) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS fare_adjusted_at TIMESTAMPTZ DEFAULT NULL;

-- =============================================================================
-- SECTION 2: AUTHORITATIVE adjust_pickup_fare RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.adjust_pickup_fare(
  p_shipment_id        UUID,
  p_final_price_amount INT,
  p_reason             TEXT,
  p_sender_agreed      BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_caller_id           UUID := auth.uid();
  v_personnel           RECORD;
  v_is_admin            BOOLEAN := FALSE;
  v_shipment            RECORD;
  v_orig_price          INT;
  v_prev_final_price    INT;
  v_sender_obligation   INT;
  v_receiver_obligation INT;
BEGIN
  -- 1. Validate inputs
  IF p_final_price_amount IS NULL OR p_final_price_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid fare amount: must be a positive integer in kobo.' USING ERRCODE = '23514';
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RAISE EXCEPTION 'Mandatory operational reason required for fare adjustment.' USING ERRCODE = '23514';
  END IF;

  IF p_sender_agreed IS NOT TRUE THEN
    RAISE EXCEPTION 'Explicit confirmation that fare was agreed with the Sender is required.' USING ERRCODE = '23514';
  END IF;

  -- 2. Lock shipment
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Check status
  IF v_shipment.current_status != 'PICKUP_IN_PROGRESS' THEN
    RAISE EXCEPTION 'Fare adjustment only allowed during active pickup. Current status: %', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  -- 3. Authorization check (Assigned Personnel or Admin or Service Role)
  IF v_caller_id IS NULL THEN
    IF current_user IN ('service_role', 'postgres', 'supabase_admin') OR 
       COALESCE(auth.jwt() ->> 'role', '') IN ('service_role', 'supabase_admin') THEN
      v_is_admin := TRUE;
      v_caller_id := COALESCE(v_shipment.assigned_pickup_personnel_id, 'cb985637-545d-49ee-b095-1fd1103e14d6'::UUID);
    ELSE
      RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF NOT v_is_admin THEN
    SELECT * INTO v_personnel FROM public.personnel WHERE id = v_caller_id AND is_active = TRUE;
    
    IF v_personnel IS NULL THEN
      -- Check if admin
      SELECT (role = 'admin') INTO v_is_admin FROM public.users WHERE id = v_caller_id;
      IF v_is_admin IS NOT TRUE THEN
        RAISE EXCEPTION 'Active personnel or admin profile required.' USING ERRCODE = '42501';
      END IF;
    ELSE
      -- Personnel checks
      IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
        RAISE EXCEPTION 'Forbidden: Only the assigned pickup Personnel may adjust the fare.' USING ERRCODE = '42501';
      END IF;

      IF v_shipment.origin_hub_id IS DISTINCT FROM v_personnel.operating_hub_id THEN
        RAISE EXCEPTION 'Forbidden: Shipment is outside your operating hub scope.' USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  -- 4. Check that cash collection has not occurred
  IF EXISTS (
    SELECT 1 FROM public.payment_collections WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER'
  ) THEN
    RAISE EXCEPTION 'Sender payment has already been collected. Fare cannot be adjusted after collection.'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payment_obligations WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER' AND status = 'COLLECTED'
  ) THEN
    RAISE EXCEPTION 'Sender payment obligation is already marked COLLECTED. Fare cannot be adjusted.'
      USING ERRCODE = '23514';
  END IF;

  v_orig_price := v_shipment.quoted_price_amount;
  v_prev_final_price := v_shipment.final_price_amount;

  -- 5. Calculate new obligations based on payment mode
  IF v_shipment.payment_mode = 'SENDER_PAYS' THEN
    v_sender_obligation   := p_final_price_amount;
    v_receiver_obligation := 0;
  ELSIF v_shipment.payment_mode = 'RECEIVER_PAYS' THEN
    v_sender_obligation   := 0;
    v_receiver_obligation := p_final_price_amount;
  ELSIF v_shipment.payment_mode = 'SPLIT_PAYMENT' THEN
    v_sender_obligation   := p_final_price_amount / 2;
    v_receiver_obligation := p_final_price_amount - v_sender_obligation;
  END IF;

  -- 6. Update shipment
  UPDATE public.shipments
  SET final_price_amount     = p_final_price_amount,
      fare_adjusted          = TRUE,
      fare_adjustment_reason = TRIM(p_reason),
      fare_adjusted_by       = v_caller_id,
      fare_adjusted_at       = NOW(),
      updated_at             = NOW()
  WHERE id = p_shipment_id;

  -- 7. Update obligations
  UPDATE public.payment_obligations
  SET expected_amount = v_sender_obligation,
      status          = CASE WHEN v_sender_obligation > 0 THEN 'PENDING' ELSE 'NOT_REQUIRED' END,
      updated_at      = NOW()
  WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';

  UPDATE public.payment_obligations
  SET expected_amount = v_receiver_obligation,
      status          = CASE WHEN v_receiver_obligation > 0 THEN 'PENDING' ELSE 'NOT_REQUIRED' END,
      updated_at      = NOW()
  WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';

  -- 8. Append single immutable FARE_ADJUSTED operational event
  INSERT INTO public.operational_events (
    aggregate_type,
    aggregate_id,
    event_type,
    actor_id,
    actor_role,
    location_hub_id,
    payload
  ) VALUES (
    'SHIPMENT',
    p_shipment_id,
    'FARE_ADJUSTED',
    v_caller_id,
    CASE WHEN v_personnel IS NOT NULL THEN 'PERSONNEL' ELSE 'ADMIN' END,
    v_shipment.origin_hub_id,
    jsonb_build_object(
      'quoted_price',          v_orig_price,
      'previous_final_price',  v_prev_final_price,
      'new_final_price',       p_final_price_amount,
      'sender_obligation',     v_sender_obligation,
      'receiver_obligation',   v_receiver_obligation,
      'reason',                TRIM(p_reason),
      'sender_agreed',         p_sender_agreed,
      'adjusted_by',           v_caller_id
    )
  );

  RETURN jsonb_build_object(
    'success',              true,
    'shipment_id',          p_shipment_id,
    'quoted_price_amount',  v_orig_price,
    'final_price_amount',   p_final_price_amount,
    'fare_adjusted',        true,
    'fare_adjustment_reason', TRIM(p_reason),
    'sender_obligation',    v_sender_obligation,
    'receiver_obligation',  v_receiver_obligation
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 3: IDEMPOTENT verify_and_correct_parcel_size
-- =============================================================================

CREATE OR REPLACE FUNCTION public.verify_and_correct_parcel_size(
  p_shipment_id         UUID,
  p_size_tier_code      TEXT,
  p_reason              TEXT DEFAULT NULL,
  p_sender_acknowledged BOOLEAN DEFAULT FALSE
)
RETURNS JSONB AS $$
DECLARE
  v_caller_id           UUID := auth.uid();
  v_personnel           RECORD;
  v_is_admin            BOOLEAN := FALSE;
  v_shipment            RECORD;
  v_parcel              RECORD;
  v_current_size_id     UUID;
  v_new_tier            RECORD;
  v_new_price           INT;
  v_orig_price          INT;
  v_sender_obligation   INT;
  v_receiver_obligation INT;
BEGIN
  IF v_caller_id IS NULL THEN
    IF current_user IN ('service_role', 'postgres', 'supabase_admin') OR 
       COALESCE(auth.jwt() ->> 'role', '') IN ('service_role', 'supabase_admin') THEN
      v_is_admin := TRUE;
      v_caller_id := 'cb985637-545d-49ee-b095-1fd1103e14d6'::UUID;
    ELSE
      RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF NOT v_is_admin THEN
    SELECT * INTO v_personnel FROM public.personnel WHERE id = v_caller_id AND is_active = TRUE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Active personnel profile required.' USING ERRCODE = '42501';
    END IF;

    IF v_shipment.assigned_pickup_personnel_id IS DISTINCT FROM v_personnel.id THEN
      RAISE EXCEPTION 'Only the assigned pickup Personnel may adjust the parcel size.' USING ERRCODE = '42501';
    END IF;

    IF v_shipment.origin_hub_id IS DISTINCT FROM v_personnel.operating_hub_id THEN
      RAISE EXCEPTION 'Shipment is not in your hub scope.' USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_shipment.current_status != 'PICKUP_IN_PROGRESS' THEN
    RAISE EXCEPTION 'Size adjustment only allowed during active pickup. Current: %', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.payment_collections WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER'
  ) THEN
    RAISE EXCEPTION 'Sender payment already collected. Size/fare cannot be adjusted after collection.' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Parcel record not found.' USING ERRCODE = 'P0002'; END IF;

  v_current_size_id := COALESCE(v_parcel.confirmed_size_id, v_parcel.sender_declared_size_id);

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

  -- Always update confirmed_size_id in parcels table
  UPDATE public.parcels
  SET confirmed_size_id = v_new_tier.id
  WHERE id = v_parcel.id;

  -- Only record correction and emit event if size tier ACTUALLY changed
  IF v_new_tier.id != v_current_size_id THEN
    INSERT INTO public.parcel_size_corrections (
      shipment_id, parcel_id, personnel_id,
      original_size_id, corrected_size_id,
      original_price_amount, corrected_price_amount,
      reason, sender_acknowledged
    ) VALUES (
      p_shipment_id, v_parcel.id, v_caller_id,
      v_current_size_id, v_new_tier.id,
      v_orig_price, v_new_price, p_reason, p_sender_acknowledged
    );

    -- If fare was NOT independently adjusted, update final_price_amount to standard tier price
    IF v_shipment.fare_adjusted IS NOT TRUE THEN
      UPDATE public.shipments SET final_price_amount = v_new_price WHERE id = p_shipment_id;

      IF v_shipment.payment_mode = 'SENDER_PAYS' THEN
        v_sender_obligation := v_new_price; v_receiver_obligation := 0;
      ELSIF v_shipment.payment_mode = 'RECEIVER_PAYS' THEN
        v_sender_obligation := 0; v_receiver_obligation := v_new_price;
      ELSIF v_shipment.payment_mode = 'SPLIT_PAYMENT' THEN
        v_sender_obligation := v_new_price / 2;
        v_receiver_obligation := v_new_price - v_sender_obligation;
      END IF;

      UPDATE public.payment_obligations SET expected_amount = v_sender_obligation, updated_at = NOW()
      WHERE shipment_id = p_shipment_id AND payer_party = 'SENDER';
      UPDATE public.payment_obligations SET expected_amount = v_receiver_obligation, updated_at = NOW()
      WHERE shipment_id = p_shipment_id AND payer_party = 'RECEIVER';
    END IF;

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'SHIPMENT', p_shipment_id, 'PARCEL_SIZE_CORRECTED',
      v_caller_id,
      CASE WHEN v_personnel IS NOT NULL THEN 'PERSONNEL' ELSE 'ADMIN' END,
      v_shipment.origin_hub_id,
      jsonb_build_object(
        'original_size_id', v_current_size_id,
        'corrected_size', v_new_tier.code,
        'original_price', v_orig_price,
        'corrected_price', v_new_price,
        'sender_acknowledged', p_sender_acknowledged,
        'reason', p_reason
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'size_tier_code', v_new_tier.code,
    'size_tier_name', v_new_tier.name,
    'quoted_price_amount', v_orig_price,
    'final_price_amount', (SELECT final_price_amount FROM public.shipments WHERE id = p_shipment_id),
    'is_corrected', (v_new_tier.id != v_current_size_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 4: GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.adjust_pickup_fare(UUID, INT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adjust_pickup_fare(UUID, INT, TEXT, BOOLEAN) TO service_role;
