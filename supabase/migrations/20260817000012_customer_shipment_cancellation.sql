-- =============================================================================
-- Cerelo V1 — Customer Shipment Cancellation Migration
-- Version: 20260817000012
-- Description: Customer-controlled cancellation lifecycle rules:
--              1. CANCEL REQUEST: In REQUESTED / before custody acceptance.
--              2. CANCEL DELIVERY: In PARCEL_CONFIRMED / origin processing before IN_TRANSIT.
--              3. HARD CUTOFF: Prohibits cancellation in IN_TRANSIT or later.
--              4. Auditable offload / unlinking from draft or confirmed batches.
--              5. Immutable operational events and payment obligation preservation.
-- =============================================================================

-- =============================================================================
-- SECTION 1: SCHEMA EXTENSIONS FOR CANCELLATION AUDIT
-- =============================================================================

ALTER TABLE public.shipments
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES auth.users(id) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS cancellation_reason_details TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS pre_cancellation_status TEXT DEFAULT NULL;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS pre_cancellation_state TEXT DEFAULT NULL;

-- =============================================================================
-- SECTION 2: AUTHORITATIVE CANCEL SHIPMENT RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.cancel_customer_shipment(
  p_shipment_id UUID,
  p_reason TEXT,
  p_reason_details TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_shipment RECORD;
  v_parcel RECORD;
  v_membership RECORD;
  v_batch RECORD;
  v_is_pre_pickup BOOLEAN;
  v_event_type TEXT;
  v_phase TEXT;
BEGIN
  -- 1. Security Check: Authenticated Caller
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Lock and Validate Shipment (Row-level lock prevents race with onboard_batch / confirm_pickup)
  SELECT * INTO v_shipment
  FROM public.shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Security: Caller must be the sender customer
  IF v_shipment.sender_customer_id != v_user_id THEN
    RAISE EXCEPTION 'Only the sender customer may cancel this shipment.' USING ERRCODE = '42501';
  END IF;

  -- 3. Idempotency Check: Already cancelled
  IF v_shipment.current_status = 'CANCELLED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'shipment_id', v_shipment.id,
      'status', 'CANCELLED',
      'already_cancelled', true,
      'message', 'Shipment is already cancelled.'
    );
  END IF;

  -- 4. HARD CUTOFF Enforcement: Reject cancellation if IN_TRANSIT or later
  IF v_shipment.current_status IN (
    'IN_TRANSIT',
    'ARRIVED_DESTINATION',
    'ARRIVED_AT_DESTINATION_HUB',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'DELIVERY_FAILED'
  ) THEN
    RAISE EXCEPTION 'This shipment is already in transit and can no longer be cancelled.'
      USING ERRCODE = '23514';
  END IF;

  -- 5. Validate Eligible Pre-cancellation Status
  IF v_shipment.current_status NOT IN (
    'REQUESTED',
    'PICKUP_IN_PROGRESS',
    'PARCEL_CONFIRMED',
    'AT_ORIGIN_HUB'
  ) THEN
    RAISE EXCEPTION 'Shipment in state % cannot be cancelled.', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  -- Distinguish Phase A (pre-pickup) vs Phase B (in-custody pre-transit)
  v_is_pre_pickup := v_shipment.current_status IN ('REQUESTED', 'PICKUP_IN_PROGRESS');

  IF v_is_pre_pickup THEN
    v_event_type := 'SHIPMENT_CANCELLED_BY_CUSTOMER';
    v_phase := 'PRE_PICKUP';
  ELSE
    v_event_type := 'DELIVERY_CANCELLED_BY_CUSTOMER';
    v_phase := 'IN_CUSTODY_PRE_TRANSIT';
  END IF;

  -- 6. Lock and Resolve Associated Parcel
  SELECT * INTO v_parcel
  FROM public.parcels
  WHERE shipment_id = p_shipment_id
  FOR UPDATE;

  -- 7. Batch & Manifest Integrity Check (if parcel was already batched)
  IF v_parcel IS NOT NULL THEN
    FOR v_membership IN
      SELECT bm.*, b.current_batch_state
      FROM public.batch_memberships bm
      JOIN public.batches b ON b.id = bm.batch_id
      WHERE bm.parcel_id = v_parcel.id AND bm.is_active = TRUE
      FOR UPDATE OF bm
    LOOP
      IF v_membership.current_batch_state = 'DRAFT' THEN
        -- Safely unlink from draft batch
        UPDATE public.batch_memberships
        SET is_active = FALSE
        WHERE id = v_membership.id;
      ELSIF v_membership.current_batch_state = 'CONFIRMED' THEN
        -- Manifest was already frozen — record auditable offload
        UPDATE public.batch_memberships
        SET is_active = FALSE
        WHERE id = v_membership.id;

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
          v_membership.batch_id,
          'PARCEL_OFFLOADED_BEFORE_DEPARTURE',
          v_user_id,
          'CUSTOMER',
          v_shipment.origin_hub_id,
          jsonb_build_object(
            'parcel_id', v_parcel.id,
            'shipment_id', p_shipment_id,
            'delivery_code', v_shipment.delivery_code,
            'reason', 'CUSTOMER_CANCELLED',
            'cancellation_reason', p_reason
          )
        );
      ELSIF v_membership.current_batch_state = 'ONBOARDED' THEN
        -- Race condition: Batch was onboarded just now
        RAISE EXCEPTION 'This shipment is already in transit and can no longer be cancelled.'
          USING ERRCODE = '23514';
      END IF;
    END LOOP;
  END IF;

  -- 8. Payment Obligations Handling:
  --    - Cancel any outstanding PENDING payment obligations
  --    - Any already COLLECTED physical payment remains intact and auditable
  UPDATE public.payment_obligations
  SET status = 'CANCELLED',
      updated_at = NOW()
  WHERE shipment_id = p_shipment_id
    AND status = 'PENDING';

  -- 9. Atomic Update: shipments table
  UPDATE public.shipments
  SET current_status = 'CANCELLED',
      cancelled_at = NOW(),
      cancelled_by = v_user_id,
      cancellation_reason = TRIM(p_reason),
      cancellation_reason_details = NULLIF(TRIM(p_reason_details), ''),
      pre_cancellation_status = v_shipment.current_status,
      updated_at = NOW()
  WHERE id = p_shipment_id;

  -- 10. Atomic Update: parcels table
  IF v_parcel IS NOT NULL THEN
    UPDATE public.parcels
    SET current_parcel_state = CASE
          WHEN v_is_pre_pickup THEN 'CANCELLED'
          ELSE 'CANCELLED_PENDING_RETURN'
        END,
        cancelled_at = NOW(),
        pre_cancellation_state = v_parcel.current_parcel_state,
        updated_at = NOW()
    WHERE id = v_parcel.id;
  END IF;

  -- 11. Immutable Audit Record: operational_events
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
    v_event_type,
    v_user_id,
    'CUSTOMER',
    v_shipment.origin_hub_id,
    jsonb_build_object(
      'delivery_code', v_shipment.delivery_code,
      'previous_status', v_shipment.current_status,
      'phase', v_phase,
      'reason', TRIM(p_reason),
      'details', NULLIF(TRIM(p_reason_details), '')
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'shipment_id', p_shipment_id,
    'delivery_code', v_shipment.delivery_code,
    'status', 'CANCELLED',
    'phase', v_phase,
    'cancelled_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.cancel_customer_shipment(UUID, TEXT, TEXT) TO authenticated;

-- =============================================================================
-- SECTION 3: REINFORCE ONBOARD_BATCH (SKIP CANCELLED PARCELS TRANSACTIONALLY)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.onboard_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
BEGIN
  -- 1. Security Check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Batch
  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id FOR UPDATE;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.current_batch_state = 'ONBOARDED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'batch_id', p_batch_id,
      'status', 'ONBOARDED',
      'already_onboarded', true
    );
  END IF;

  IF v_batch.current_batch_state != 'CONFIRMED' THEN
    RAISE EXCEPTION 'Batch must be CONFIRMED before it can be onboarded (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  -- 3. Atomic State Updates: Batch
  UPDATE public.batches
  SET current_batch_state = 'ONBOARDED',
      onboarded_by_personnel_id = v_personnel.id,
      onboarded_at = NOW()
  WHERE id = p_batch_id;

  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs
    SET status = 'DEPARTED',
        actual_departure_at = NOW()
    WHERE id = v_batch.transit_run_id;
  END IF;

  -- 4. Atomic State Updates: Only non-cancelled active member parcels
  FOR v_parcel IN
    SELECT p.*, bm.id as membership_id, s.current_status as shipment_status
    FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    JOIN public.shipments s ON s.id = p.shipment_id
    WHERE bm.batch_id = p_batch_id
      AND bm.is_active = TRUE
      AND p.current_parcel_state NOT IN ('CANCELLED', 'CANCELLED_PENDING_RETURN')
      AND s.current_status != 'CANCELLED'
    FOR UPDATE OF p
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'CORRIDOR_TRANSIT',
        current_custody_type = 'TRANSIT_PARTNER',
        updated_at = NOW()
    WHERE id = v_parcel.id;

    UPDATE public.shipments
    SET current_status = 'IN_TRANSIT',
        updated_at = NOW()
    WHERE id = v_parcel.shipment_id;

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
      'PARCEL_DEPARTED_ON_CORRIDOR',
      v_user_id,
      'PERSONNEL',
      v_batch.origin_hub_id,
      jsonb_build_object(
        'batch_id', p_batch_id,
        'batch_reference', v_batch.batch_reference,
        'shipment_id', v_parcel.shipment_id
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'batch_reference', v_batch.batch_reference,
    'status', 'ONBOARDED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.onboard_batch(UUID) TO authenticated;
