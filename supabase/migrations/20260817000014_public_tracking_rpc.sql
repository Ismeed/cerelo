-- =============================================================================
-- Cerelo V1 — Public Shipment Tracking RPC Migration
-- Version: 20260817000014
-- Description: Server-authoritative, privacy-preserving public tracking query
--              supporting both Delivery Code lookup and Share Token resolution
--              with strictly allow-listed response projections (zero PII leakage).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_public_shipment_tracking(p_tracking_query TEXT)
RETURNS JSONB AS $$
DECLARE
  v_cleaned TEXT;
  v_formatted_code TEXT;
  v_shipment RECORD;
  v_parcel RECORD;
  v_share RECORD;
  v_milestones JSONB := '[]'::jsonb;
  v_category TEXT := 'General Package';
  v_sender_first_name TEXT;
  v_receiver_masked_phone TEXT;
BEGIN
  -- 1. Input sanitization & preliminary validation
  IF p_tracking_query IS NULL OR TRIM(p_tracking_query) = '' THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'EMPTY_QUERY'
    );
  END IF;

  v_cleaned := regexp_replace(UPPER(TRIM(p_tracking_query)), '[\s\-]', '', 'g');

  -- ── ACCESS PATH A: DELIVERY CODE LOOKUP ───────────────────────────────────
  -- Pattern: CRL followed by 8 characters from Base32 set (e.g. CRL-2B8K-9X4M)
  IF v_cleaned ~ '^CRL[2-9A-HJ-NP-Z]{8}$' THEN
    v_formatted_code := 'CRL-' || substr(v_cleaned, 4, 4) || '-' || substr(v_cleaned, 8, 4);

    SELECT * INTO v_shipment
    FROM public.shipments
    WHERE delivery_code = v_formatted_code;

    IF v_shipment IS NULL THEN
      RETURN jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    -- Fetch category description
    SELECT category_description INTO v_category
    FROM public.parcels
    WHERE shipment_id = v_shipment.id;

    -- Fetch safe verified milestone events (strictly allow-listed types)
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'event_type', oe.event_type,
          'created_at', oe.created_at
        ) ORDER BY oe.created_at ASC
      ),
      '[]'::jsonb
    ) INTO v_milestones
    FROM public.operational_events oe
    WHERE (
      oe.aggregate_id = v_shipment.id
      OR oe.aggregate_id IN (SELECT id FROM public.parcels WHERE shipment_id = v_shipment.id)
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
      'SHIPMENT_ARRIVED_DESTINATION',
      'PARCEL_OUT_FOR_DELIVERY',
      'SHIPMENT_DELIVERED_TO_RECEIVER',
      'SHIPMENT_CANCELLED_BY_CUSTOMER',
      'DELIVERY_CANCELLED_BY_CUSTOMER'
    );

    -- Minimal disclosure projection: zero PII
    RETURN jsonb_build_object(
      'is_valid', true,
      'lookup_type', 'DELIVERY_CODE',
      'delivery_code', v_shipment.delivery_code,
      'origin_city', v_shipment.origin_city,
      'destination_city', v_shipment.destination_city,
      'current_status', v_shipment.current_status,
      'category_description', COALESCE(v_category, 'General Package'),
      'created_at', v_shipment.created_at,
      'delivered_at', v_shipment.delivered_at,
      'cancelled_at', v_shipment.cancelled_at,
      'milestones', v_milestones
    );

  -- ── ACCESS PATH B: SHARE TOKEN RESOLUTION ──────────────────────────────────
  -- Pattern: 32 hex characters (e.g. a1b2c3d4e5f6...)
  ELSIF v_cleaned ~ '^[A-F0-9]{32}$' THEN
    SELECT * INTO v_share
    FROM public.share_tokens
    WHERE token = LOWER(v_cleaned)
      AND is_revoked = FALSE
      AND expires_at > NOW();

    IF v_share IS NULL THEN
      RETURN jsonb_build_object(
        'is_valid', false,
        'error', 'INVALID_OR_EXPIRED_TOKEN'
      );
    END IF;

    SELECT * INTO v_shipment
    FROM public.shipments
    WHERE id = v_share.shipment_id;

    IF v_shipment IS NULL THEN
      RETURN jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    -- Fetch category description
    SELECT category_description INTO v_category
    FROM public.parcels
    WHERE shipment_id = v_shipment.id;

    -- Fetch safe verified milestone events
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'event_type', oe.event_type,
          'created_at', oe.created_at
        ) ORDER BY oe.created_at ASC
      ),
      '[]'::jsonb
    ) INTO v_milestones
    FROM public.operational_events oe
    WHERE (
      oe.aggregate_id = v_shipment.id
      OR oe.aggregate_id IN (SELECT id FROM public.parcels WHERE shipment_id = v_shipment.id)
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
      'SHIPMENT_ARRIVED_DESTINATION',
      'PARCEL_OUT_FOR_DELIVERY',
      'SHIPMENT_DELIVERED_TO_RECEIVER',
      'SHIPMENT_CANCELLED_BY_CUSTOMER',
      'DELIVERY_CANCELLED_BY_CUSTOMER'
    );

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
      'lookup_type', 'SHARE_TOKEN',
      'delivery_code', v_shipment.delivery_code,
      'origin_city', v_shipment.origin_city,
      'destination_city', v_shipment.destination_city,
      'current_status', v_shipment.current_status,
      'sender_display_name', v_sender_first_name,
      'receiver_name_snapshot', v_shipment.receiver_name_snapshot,
      'receiver_phone_masked', v_receiver_masked_phone,
      'category_description', COALESCE(v_category, 'General Package'),
      'created_at', v_shipment.created_at,
      'delivered_at', v_shipment.delivered_at,
      'cancelled_at', v_shipment.cancelled_at,
      'milestones', v_milestones
    );

  -- ── INVALID FORMAT ────────────────────────────────────────────────────────
  ELSE
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'INVALID_CREDENTIAL_FORMAT'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- Grant execution to public / unauthenticated visitors and authenticated users
GRANT EXECUTE ON FUNCTION public.get_public_shipment_tracking(TEXT) TO anon, authenticated, service_role;
