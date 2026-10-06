-- =============================================================================
-- Cerelo V1 — Destination Reconciliation & Final-Mile Delivery Migration
-- Version: 20260817000008
-- Description: Destination Batch arrival, parcel reconciliation, final-mile queue,
--              receiver physical cash collection, atomic delivery handover,
--              sender completion call SOP, and receiver acknowledgement.
-- =============================================================================

-- =============================================================================
-- SECTION 1: RECONCILIATION DISPOSITIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.batch_reconciliation_records (
  id                         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  batch_id                   UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
  parcel_id                  UUID NOT NULL REFERENCES public.parcels(id) ON DELETE CASCADE,
  disposition                TEXT NOT NULL
                               CHECK (disposition IN ('PRESENT', 'MISSING', 'UNEXPECTED', 'DAMAGED', 'WRONG_BATCH')),
  reconciled_by_personnel_id UUID NOT NULL REFERENCES public.personnel(id),
  reconciled_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes                      TEXT,
  UNIQUE (batch_id, parcel_id)
);

CREATE TABLE IF NOT EXISTS public.delivery_attempts (
  id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id              UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  attempted_by_personnel_id UUID NOT NULL REFERENCES public.personnel(id),
  outcome                  TEXT NOT NULL
                             CHECK (outcome IN ('DELIVERED', 'RECEIVER_UNAVAILABLE', 'RECEIVER_REFUSED', 'PAYMENT_REFUSED', 'WRONG_ADDRESS', 'DAMAGED')),
  notes                    TEXT,
  attempted_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add completion metadata to shipments table
ALTER TABLE public.shipments
  ADD COLUMN IF NOT EXISTS delivered_by_personnel_id UUID REFERENCES public.personnel(id),
  ADD COLUMN IF NOT EXISTS sender_completion_call_outcome TEXT,
  ADD COLUMN IF NOT EXISTS sender_completion_call_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receiver_confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receiver_confirmed_by_customer_id UUID REFERENCES public.customers(id);

CREATE INDEX IF NOT EXISTS idx_reconciliation_batch ON public.batch_reconciliation_records(batch_id);
CREATE INDEX IF NOT EXISTS idx_delivery_attempts_shipment ON public.delivery_attempts(shipment_id);

ALTER TABLE public.batch_reconciliation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Personnel can view reconciliation records"
  ON public.batch_reconciliation_records FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

CREATE POLICY "Personnel can view delivery attempts"
  ON public.delivery_attempts FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

-- =============================================================================
-- SECTION 2: DESTINATION BATCH RECEIPT & RECONCILIATION RPCS
-- =============================================================================

-- 1. Receive Destination Batch RPC
CREATE OR REPLACE FUNCTION public.receive_destination_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.current_batch_state = 'DESTINATION_RECEIVED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'batch_id', p_batch_id,
      'status', 'DESTINATION_RECEIVED',
      'already_received', true
    );
  END IF;

  IF v_batch.current_batch_state != 'ONBOARDED' THEN
    RAISE EXCEPTION 'Batch is not in transit (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  -- Atomic State Update: Batch Arrived
  UPDATE public.batches
  SET current_batch_state = 'DESTINATION_RECEIVED'
  WHERE id = p_batch_id;

  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs
    SET status = 'ARRIVED',
        actual_arrival_at = NOW()
    WHERE id = v_batch.transit_run_id;
  END IF;

  -- Update member parcels and shipments to ARRIVED_DESTINATION
  FOR v_parcel IN
    SELECT p.*
    FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'DESTINATION_HUB_STAGED',
        current_custody_type = 'HUB'
    WHERE id = v_parcel.id;

    UPDATE public.shipments
    SET current_status = 'ARRIVED_DESTINATION'
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
      'SHIPMENT',
      v_parcel.shipment_id,
      'SHIPMENT_ARRIVED_DESTINATION',
      v_personnel.id,
      'PERSONNEL',
      v_batch.destination_hub_id,
      jsonb_build_object('status', 'ARRIVED_DESTINATION')
    );
  END LOOP;

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
    p_batch_id,
    'BATCH_DESTINATION_RECEIVED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object('batch_reference', v_batch.batch_reference)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'status', 'DESTINATION_RECEIVED',
    'already_received', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Reconcile Individual Batch Parcel RPC
CREATE OR REPLACE FUNCTION public.reconcile_batch_parcel(
  p_batch_id UUID,
  p_parcel_id UUID,
  p_disposition TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.batch_reconciliation_records (
    batch_id,
    parcel_id,
    disposition,
    reconciled_by_personnel_id,
    notes
  )
  VALUES (
    p_batch_id,
    p_parcel_id,
    UPPER(p_disposition),
    v_personnel.id,
    p_notes
  )
  ON CONFLICT (batch_id, parcel_id)
  DO UPDATE SET
    disposition = UPPER(p_disposition),
    notes = p_notes,
    reconciled_at = NOW();

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
    p_parcel_id,
    'PARCEL_RECONCILED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object('batch_id', p_batch_id, 'disposition', UPPER(p_disposition))
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'parcel_id', p_parcel_id,
    'disposition', UPPER(p_disposition)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Complete Batch Reconciliation RPC
CREATE OR REPLACE FUNCTION public.complete_batch_reconciliation(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_expected_count INT;
  v_reconciled_count INT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT COUNT(*) INTO v_expected_count
  FROM public.batch_memberships
  WHERE batch_id = p_batch_id AND is_active = TRUE;

  SELECT COUNT(*) INTO v_reconciled_count
  FROM public.batch_reconciliation_records
  WHERE batch_id = p_batch_id;

  IF v_reconciled_count < v_expected_count THEN
    RAISE EXCEPTION 'Cannot complete reconciliation: % of % expected parcels reconciled.', v_reconciled_count, v_expected_count
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.batches
  SET current_batch_state = 'RECONCILED'
  WHERE id = p_batch_id;

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
    p_batch_id,
    'BATCH_RECONCILIATION_COMPLETED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object('reconciled_count', v_reconciled_count)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'status', 'RECONCILED'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 3: FINAL-MILE DELIVERY RPCS
-- =============================================================================

-- 1. Get Destination Ready for Delivery Queue RPC
CREATE OR REPLACE FUNCTION public.get_ready_for_delivery_queue()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
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
    ) ORDER BY s.created_at ASC
  ) INTO v_result
  FROM public.shipments s
  JOIN public.parcels p ON p.shipment_id = s.id
  JOIN public.parcel_size_tiers pst ON pst.id = COALESCE(p.confirmed_size_id, p.sender_declared_size_id)
  LEFT JOIN public.payment_obligations po ON po.shipment_id = s.id AND po.payer_party = 'RECEIVER'
  WHERE s.current_status IN ('ARRIVED_DESTINATION', 'OUT_FOR_DELIVERY');

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Start Final Delivery (Going for Delivery) RPC
CREATE OR REPLACE FUNCTION public.start_final_delivery(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_parcel RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status = 'OUT_FOR_DELIVERY' THEN
    RETURN jsonb_build_object('success', true, 'status', 'OUT_FOR_DELIVERY', 'already_started', true);
  END IF;

  IF v_shipment.current_status != 'ARRIVED_DESTINATION' THEN
    RAISE EXCEPTION 'Shipment is not ready for final delivery (current status: %)', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;

  UPDATE public.shipments
  SET current_status = 'OUT_FOR_DELIVERY'
  WHERE id = p_shipment_id;

  UPDATE public.parcels
  SET current_parcel_state = 'FINAL_DELIVERY_STAGED',
      current_custody_type = 'PERSONNEL',
      current_custody_holder_id = v_personnel.id
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
    jsonb_build_object('status', 'OUT_FOR_DELIVERY')
  );

  RETURN jsonb_build_object('success', true, 'status', 'OUT_FOR_DELIVERY', 'already_started', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Atomic Mark Delivered RPC (Handover completed)
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
  -- 1. Security Check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Shipment
  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.current_status = 'DELIVERED' THEN
    RETURN jsonb_build_object('success', true, 'status', 'DELIVERED', 'already_delivered', true);
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

  SELECT * INTO v_parcel FROM public.parcels WHERE shipment_id = p_shipment_id;

  -- 4. Atomic Delivery Completion
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
    'Parcel physically handed over to receiver.'
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
    jsonb_build_object('status', 'DELIVERED', 'delivered_by', v_personnel.full_name)
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
    jsonb_build_object('from_custody', 'PERSONNEL', 'to_custody', 'RECEIVER')
  );

  RETURN jsonb_build_object('success', true, 'status', 'DELIVERED', 'already_delivered', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Record Sender Completion Call (Doorstep SOP) RPC
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
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Customer Receiver Confirmation (Secondary Acknowledgment) RPC
CREATE OR REPLACE FUNCTION public.confirm_receiver_receipt(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_customer RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer account required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_shipment.receiver_customer_id != v_customer.id AND v_shipment.receiver_phone_snapshot != v_customer.phone_number THEN
    RAISE EXCEPTION 'Forbidden: You are not the receiver of this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'DELIVERED' THEN
    RAISE EXCEPTION 'Shipment is not yet delivered.' USING ERRCODE = '23514';
  END IF;

  IF v_shipment.receiver_confirmed_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'already_confirmed', true);
  END IF;

  UPDATE public.shipments
  SET receiver_confirmed_at = NOW(),
      receiver_confirmed_by_customer_id = v_customer.id
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
    'RECEIVER_RECEIPT_CONFIRMED',
    v_customer.id,
    'CUSTOMER',
    v_shipment.destination_hub_id,
    jsonb_build_object('confirmed_at', NOW())
  );

  RETURN jsonb_build_object('success', true, 'already_confirmed', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.receive_destination_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_batch_parcel(UUID, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_batch_reconciliation(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ready_for_delivery_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_final_delivery(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_delivered(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_sender_completion_call(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_receiver_receipt(UUID) TO authenticated;
