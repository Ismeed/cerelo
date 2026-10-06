-- =============================================================================
-- Cerelo V1 — Mark Delivered Receiver-Obligation Block Fix
-- Version: 20260817000019
-- Description:
--   Fixes mark_delivered to reliably block delivery when a RECEIVER payment
--   obligation is PENDING and unpaid.
--
--   Root cause of previous behaviour:
--     The SELECT * INTO v_receiver_obligation pattern with IS NOT NULL check is
--     unreliable in SECURITY DEFINER context when RLS evaluation order is
--     involved. Replaced with:
--       (a) SET LOCAL row_security = off  — guarantees internal checks bypass RLS
--       (b) PERFORM ... IF FOUND pattern — unambiguous row-existence test
--       (c) Explicit sub-select for obligation amount — no RECORD NULL ambiguity
--
-- Do NOT edit migrations 01–18.
-- Schema parity: apply to BOTH staging and production.
-- =============================================================================

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
  -- Bypass RLS for internal obligation checks inside this SECURITY DEFINER function.
  -- The function is called only by authenticated, role-verified Personnel;
  -- internal reads (payment_obligations, shipments, parcels) must not be filtered.
  SET LOCAL row_security = off;

  -- 1. Security: active Personnel identity
  SELECT * INTO v_personnel
  FROM public.personnel
  WHERE user_id = v_user_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate shipment & state precondition
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

  IF v_shipment.current_status != 'OUT_FOR_DELIVERY' THEN
    RAISE EXCEPTION
      'Shipment must be OUT_FOR_DELIVERY before it can be marked DELIVERED (current: %)',
      v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  -- 3. Payment precondition: RECEIVER obligation must be COLLECTED before delivery.
  --    Uses PERFORM + IF FOUND to avoid any SELECT INTO RECORD NULL ambiguity.
  --    Only fires when expected_amount > 0 (i.e. NOT_REQUIRED obligations are skipped).

  SELECT expected_amount INTO v_receiver_amount
  FROM public.payment_obligations
  WHERE shipment_id = p_shipment_id
    AND payer_party  = 'RECEIVER'
    AND expected_amount > 0;

  IF FOUND AND v_receiver_amount > 0 THEN
    -- Verify it is actually COLLECTED
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
      current_custody_holder_id = NULL
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

-- Companion overload (optional delivery code — passes through to primary)
CREATE OR REPLACE FUNCTION public.mark_delivered(
  p_shipment_id     UUID,
  p_delivery_code   TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
  -- Delivery Code is an operational identifier/lookup fallback only.
  -- It is NOT a mandatory receiver PIN. Authorization is via Personnel JWT.
  RETURN public.mark_delivered(p_shipment_id, p_idempotency_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- Grants
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT, TEXT)  TO authenticated;
