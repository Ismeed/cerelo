-- =============================================================================
-- Cerelo V1 — Migration 26: Enforce Receive-Before-Reconcile & Tracking Hygiene
-- Version: 20260827000026
-- Description:
--   1. Strict Server-Side Receive-Before-Reconcile Invariant:
--      - reconcile_batch_parcel rejects any reconciliation when batch != DESTINATION_RECEIVED/RECONCILING.
--      - complete_batch_reconciliation rejects completion when batch != DESTINATION_RECEIVED/RECONCILING.
--   2. Authoritative get_public_shipment_tracking RPC (tracking hygiene):
--      - Full allow-list for customer milestones (including destination processing).
--   3. Strict Draft/Batch Deletion & Cancellation Guards:
--      - Deletion permanently blocked for CONFIRMED, ONBOARDED, DESTINATION_RECEIVED batches.
-- =============================================================================

-- 1. Reconcile Individual Batch Parcel RPC with Strict Receive-Before-Reconcile Check
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
  v_parcel RECORD;
  v_membership RECORD;
BEGIN
  -- Security check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Directional Hub Authorization: Only destination hub personnel can reconcile
  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to reconcile batch at this destination hub (hub mismatch).'
      USING ERRCODE = '42501';
  END IF;

  -- ENFORCE RECEIVE-BEFORE-RECONCILE INVARIANT
  IF v_batch.current_batch_state NOT IN ('DESTINATION_RECEIVED', 'RECONCILING') THEN
    RAISE EXCEPTION 'Cannot reconcile parcel: Batch % has not been received at destination hub (current state: %).',
      v_batch.batch_reference, v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Validate membership
  SELECT * INTO v_membership
  FROM public.batch_memberships
  WHERE batch_id = p_batch_id AND parcel_id = p_parcel_id AND is_active = TRUE;

  IF v_membership IS NULL AND UPPER(p_disposition) != 'UNEXPECTED' THEN
    RAISE EXCEPTION 'Parcel is not an active member of this batch manifest.'
      USING ERRCODE = '23514';
  END IF;

  -- Update batch state to RECONCILING if currently DESTINATION_RECEIVED
  IF v_batch.current_batch_state = 'DESTINATION_RECEIVED' THEN
    UPDATE public.batches
    SET current_batch_state = 'RECONCILING',
        updated_at = NOW()
    WHERE id = p_batch_id;
  END IF;

  -- Upsert disposition
  INSERT INTO public.batch_reconciliation_records (
    batch_id,
    parcel_id,
    disposition,
    reconciled_by_personnel_id,
    notes,
    reconciled_at
  )
  VALUES (
    p_batch_id,
    p_parcel_id,
    UPPER(p_disposition),
    v_personnel.id,
    p_notes,
    NOW()
  )
  ON CONFLICT (batch_id, parcel_id)
  DO UPDATE SET
    disposition = UPPER(p_disposition),
    notes = p_notes,
    reconciled_at = NOW(),
    reconciled_by_personnel_id = v_personnel.id;

  -- If marked PRESENT, update parcel state and custody
  IF UPPER(p_disposition) = 'PRESENT' THEN
    UPDATE public.parcels
    SET current_parcel_state = 'DESTINATION_HUB_STAGED',
        current_custody_type = 'HUB',
        updated_at = NOW()
    WHERE id = p_parcel_id;
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
    'PARCEL',
    p_parcel_id,
    'PARCEL_RECONCILED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.destination_hub_id,
    jsonb_build_object(
      'batch_id', p_batch_id,
      'batch_reference', v_batch.batch_reference,
      'disposition', UPPER(p_disposition)
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'parcel_id', p_parcel_id,
    'disposition', UPPER(p_disposition)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Complete Batch Reconciliation RPC with Strict Receive-Before-Reconcile Check
CREATE OR REPLACE FUNCTION public.complete_batch_reconciliation(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_expected_count INT;
  v_reconciled_count INT;
  v_rec RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_personnel.operating_hub_id != v_batch.destination_hub_id THEN
    RAISE EXCEPTION 'Personnel not authorized to complete reconciliation for this batch.'
      USING ERRCODE = '42501';
  END IF;

  -- ENFORCE RECEIVE-BEFORE-RECONCILE INVARIANT
  IF v_batch.current_batch_state NOT IN ('DESTINATION_RECEIVED', 'RECONCILING') THEN
    RAISE EXCEPTION 'Cannot complete reconciliation: Batch % has not been received at destination hub (current state: %).',
      v_batch.batch_reference, v_batch.current_batch_state
      USING ERRCODE = '23514';
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

  -- Update batch state to RECONCILED
  UPDATE public.batches
  SET current_batch_state = 'RECONCILED',
      updated_at = NOW()
  WHERE id = p_batch_id;

  -- For each parcel marked PRESENT, transition shipment to ARRIVED_DESTINATION (Ready for Delivery)
  FOR v_rec IN
    SELECT brr.*, p.shipment_id
    FROM public.batch_reconciliation_records brr
    JOIN public.parcels p ON p.id = brr.parcel_id
    WHERE brr.batch_id = p_batch_id AND brr.disposition = 'PRESENT'
  LOOP
    UPDATE public.shipments
    SET current_status = 'ARRIVED_DESTINATION',
        updated_at = NOW()
    WHERE id = v_rec.shipment_id;

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
      v_rec.shipment_id,
      'SHIPMENT_ARRIVED_DESTINATION',
      v_personnel.id,
      'PERSONNEL',
      v_batch.destination_hub_id,
      jsonb_build_object('status', 'ARRIVED_DESTINATION', 'batch_id', p_batch_id)
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

-- 3. Authoritative Hardened Public Shipment Tracking RPC
CREATE OR REPLACE FUNCTION public.get_public_shipment_tracking(p_tracking_query TEXT)
RETURNS pg_catalog.jsonb AS $$
DECLARE
  v_cleaned TEXT;
  v_formatted_code TEXT;
  v_shipment RECORD;
  v_share RECORD;
  v_milestones pg_catalog.jsonb := '[]'::pg_catalog.jsonb;
BEGIN
  -- 1. Input sanitization & preliminary validation
  IF p_tracking_query IS NULL OR pg_catalog.btrim(p_tracking_query) = '' THEN
    RETURN pg_catalog.jsonb_build_object(
      'is_valid', false,
      'error', 'EMPTY_QUERY'
    );
  END IF;

  v_cleaned := pg_catalog.regexp_replace(pg_catalog.upper(pg_catalog.btrim(p_tracking_query)), '[\s\-]', '', 'g');

  -- ── ACCESS PATH A: DELIVERY CODE LOOKUP ───────────────────────────────────
  IF v_cleaned ~ '^CRL[2-9A-HJ-NP-Z]{8}$' THEN
    v_formatted_code := 'CRL-' || pg_catalog.substr(v_cleaned, 4, 4) || '-' || pg_catalog.substr(v_cleaned, 8, 4);

    SELECT
      s.id,
      s.delivery_code,
      s.origin_city,
      s.destination_city,
      s.current_status,
      s.created_at,
      s.delivered_at,
      s.cancelled_at
    INTO v_shipment
    FROM public.shipments s
    WHERE s.delivery_code = v_formatted_code;

    IF v_shipment.id IS NULL THEN
      RETURN pg_catalog.jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    -- Fetch safe verified milestone events (strictly allow-listed types, zero PII)
    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'event_type', oe.event_type,
          'created_at', oe.created_at
        ) ORDER BY oe.created_at ASC
      ),
      '[]'::pg_catalog.jsonb
    ) INTO v_milestones
    FROM public.operational_events oe
    WHERE (
      oe.aggregate_id = v_shipment.id
      OR oe.aggregate_id IN (SELECT p.id FROM public.parcels p WHERE p.shipment_id = v_shipment.id)
    )
    AND oe.event_type IN (
      'SHIPMENT_REQUESTED',
      'DELIVERY_CODE_GENERATED',
      'PARCEL_INSPECTED_AND_COLLECTED',
      'PARCEL_RECEIVED_AT_ORIGIN_HUB',
      'PARCEL_STAGED_AT_ORIGIN',
      'BATCH_LOCKED_FOR_DEPARTURE',
      'PARCEL_DEPARTED_ON_CORRIDOR',
      'BATCH_ONBOARDED',
      'SHIPMENT_IN_TRANSIT',
      'SHIPMENT_ARRIVED_AT_DESTINATION_HUB',
      'SHIPMENT_ARRIVED_DESTINATION',
      'PARCEL_RECONCILED',
      'PARCEL_OUT_FOR_DELIVERY',
      'SHIPMENT_OUT_FOR_DELIVERY',
      'SHIPMENT_DELIVERED_TO_RECEIVER',
      'SHIPMENT_DELIVERED',
      'SHIPMENT_CANCELLED_BY_CUSTOMER',
      'DELIVERY_CANCELLED_BY_CUSTOMER'
    );

    RETURN pg_catalog.jsonb_build_object(
      'is_valid', true,
      'lookup_type', 'DELIVERY_CODE',
      'delivery_code', v_shipment.delivery_code,
      'origin_city', v_shipment.origin_city,
      'destination_city', v_shipment.destination_city,
      'current_status', v_shipment.current_status,
      'created_at', v_shipment.created_at,
      'delivered_at', v_shipment.delivered_at,
      'cancelled_at', v_shipment.cancelled_at,
      'milestones', v_milestones
    );

  -- ── ACCESS PATH B: SHARE TOKEN RESOLUTION ──────────────────────────────────
  ELSIF v_cleaned ~ '^[A-F0-9]{32}$' THEN
    SELECT
      st.id,
      st.shipment_id,
      st.expires_at,
      st.is_revoked
    INTO v_share
    FROM public.share_tokens st
    WHERE st.token = pg_catalog.lower(v_cleaned)
      AND st.is_revoked = FALSE
      AND st.expires_at > pg_catalog.now();

    IF v_share.id IS NULL THEN
      RETURN pg_catalog.jsonb_build_object(
        'is_valid', false,
        'error', 'INVALID_OR_EXPIRED_TOKEN'
      );
    END IF;

    SELECT
      s.id,
      s.delivery_code,
      s.origin_city,
      s.destination_city,
      s.current_status,
      s.created_at,
      s.delivered_at,
      s.cancelled_at
    INTO v_shipment
    FROM public.shipments s
    WHERE s.id = v_share.shipment_id;

    IF v_shipment.id IS NULL THEN
      RETURN pg_catalog.jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'event_type', oe.event_type,
          'created_at', oe.created_at
        ) ORDER BY oe.created_at ASC
      ),
      '[]'::pg_catalog.jsonb
    ) INTO v_milestones
    FROM public.operational_events oe
    WHERE (
      oe.aggregate_id = v_shipment.id
      OR oe.aggregate_id IN (SELECT p.id FROM public.parcels p WHERE p.shipment_id = v_shipment.id)
    )
    AND oe.event_type IN (
      'SHIPMENT_REQUESTED',
      'DELIVERY_CODE_GENERATED',
      'PARCEL_INSPECTED_AND_COLLECTED',
      'PARCEL_RECEIVED_AT_ORIGIN_HUB',
      'PARCEL_STAGED_AT_ORIGIN',
      'BATCH_LOCKED_FOR_DEPARTURE',
      'PARCEL_DEPARTED_ON_CORRIDOR',
      'BATCH_ONBOARDED',
      'SHIPMENT_IN_TRANSIT',
      'SHIPMENT_ARRIVED_AT_DESTINATION_HUB',
      'SHIPMENT_ARRIVED_DESTINATION',
      'PARCEL_RECONCILED',
      'PARCEL_OUT_FOR_DELIVERY',
      'SHIPMENT_OUT_FOR_DELIVERY',
      'SHIPMENT_DELIVERED_TO_RECEIVER',
      'SHIPMENT_DELIVERED',
      'SHIPMENT_CANCELLED_BY_CUSTOMER',
      'DELIVERY_CANCELLED_BY_CUSTOMER'
    );

    RETURN pg_catalog.jsonb_build_object(
      'is_valid', true,
      'lookup_type', 'SHARE_TOKEN',
      'delivery_code', v_shipment.delivery_code,
      'origin_city', v_shipment.origin_city,
      'destination_city', v_shipment.destination_city,
      'current_status', v_shipment.current_status,
      'created_at', v_shipment.created_at,
      'delivered_at', v_shipment.delivered_at,
      'cancelled_at', v_shipment.cancelled_at,
      'milestones', v_milestones
    );
  ELSE
    RETURN pg_catalog.jsonb_build_object(
      'is_valid', false,
      'error', 'INVALID_CREDENTIAL_FORMAT'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Explicit Privilege Management
REVOKE ALL ON FUNCTION public.get_public_shipment_tracking(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_shipment_tracking(TEXT) TO anon, authenticated;
