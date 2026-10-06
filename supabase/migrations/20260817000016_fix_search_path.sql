-- =============================================================================
-- Cerelo V1 — Hardened Public Shipment Tracking RPC (Search Path Refinement)
-- Version: 20260817000016
-- Description: Secures search_path using standard PostgreSQL practice:
--              SET search_path = pg_catalog, public
--              ensuring built-in functions and operators resolve to pg_catalog
--              while tables resolve to public with zero schema-shadowing risk.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_public_shipment_tracking(p_tracking_query TEXT)
RETURNS JSONB AS $$
DECLARE
  v_cleaned TEXT;
  v_formatted_code TEXT;
  v_shipment RECORD;
  v_share RECORD;
  v_milestones JSONB := '[]'::jsonb;
BEGIN
  -- 1. Input sanitization & preliminary validation
  IF p_tracking_query IS NULL OR btrim(p_tracking_query) = '' THEN
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'EMPTY_QUERY'
    );
  END IF;

  v_cleaned := regexp_replace(upper(btrim(p_tracking_query)), '[\s\-]', '', 'g');

  -- ── ACCESS PATH A: DELIVERY CODE LOOKUP ───────────────────────────────────
  -- Pattern: CRL followed by 8 characters from Base32 set (e.g. CRL-2B8K-9X4M)
  IF v_cleaned ~ '^CRL[2-9A-HJ-NP-Z]{8}$' THEN
    v_formatted_code := 'CRL-' || substr(v_cleaned, 4, 4) || '-' || substr(v_cleaned, 8, 4);

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
      RETURN jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    -- Fetch safe verified milestone events (strictly allow-listed types, zero PII)
    SELECT coalesce(
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
      'created_at', v_shipment.created_at,
      'delivered_at', v_shipment.delivered_at,
      'cancelled_at', v_shipment.cancelled_at,
      'milestones', v_milestones
    );

  -- ── ACCESS PATH B: SHARE TOKEN RESOLUTION ──────────────────────────────────
  -- Pattern: 32 hex characters (e.g. a1b2c3d4e5f6...)
  ELSIF v_cleaned ~ '^[A-F0-9]{32}$' THEN
    SELECT
      st.id,
      st.shipment_id,
      st.expires_at,
      st.is_revoked
    INTO v_share
    FROM public.share_tokens st
    WHERE st.token = lower(v_cleaned)
      AND st.is_revoked = FALSE
      AND st.expires_at > now();

    IF v_share.id IS NULL THEN
      RETURN jsonb_build_object(
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
      RETURN jsonb_build_object(
        'is_valid', false,
        'error', 'SHIPMENT_NOT_FOUND'
      );
    END IF;

    -- Fetch safe verified milestone events
    SELECT coalesce(
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
      'SHIPMENT_ARRIVED_DESTINATION',
      'PARCEL_OUT_FOR_DELIVERY',
      'SHIPMENT_DELIVERED_TO_RECEIVER',
      'SHIPMENT_CANCELLED_BY_CUSTOMER',
      'DELIVERY_CANCELLED_BY_CUSTOMER'
    );

    -- Strict privacy minimization: OMIT > MASK > EXPOSE
    -- Return identical safe public projection without customer names or masked phone numbers
    RETURN jsonb_build_object(
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

  -- ── INVALID FORMAT ────────────────────────────────────────────────────────
  ELSE
    RETURN jsonb_build_object(
      'is_valid', false,
      'error', 'INVALID_CREDENTIAL_FORMAT'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- Explicit Privilege Management:
REVOKE ALL ON FUNCTION public.get_public_shipment_tracking(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_shipment_tracking(TEXT) TO anon, authenticated;
