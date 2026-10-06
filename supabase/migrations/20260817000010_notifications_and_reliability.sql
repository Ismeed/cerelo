-- =============================================================================
-- Cerelo V1 — Notifications, Exceptions & Operational Reliability Migration
-- Version: 20260817000010
-- Description: Device token registrations, transactional notification outbox,
--              stuck-work operational attention queries, and read-only system
--              integrity verification functions.
-- =============================================================================

-- =============================================================================
-- SECTION 1: DEVICE REGISTRATIONS TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.device_registrations (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  platform     TEXT NOT NULL CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, device_token)
);

CREATE INDEX IF NOT EXISTS idx_device_user ON public.device_registrations(user_id) WHERE is_active = TRUE;

ALTER TABLE public.device_registrations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own device registrations"
  ON public.device_registrations FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- SECTION 2: NOTIFICATION OUTBOX TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.notification_outbox (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type        TEXT NOT NULL,
  aggregate_type    TEXT NOT NULL,
  aggregate_id      UUID NOT NULL,
  payload           JSONB NOT NULL,
  status            TEXT NOT NULL DEFAULT 'PENDING'
                      CHECK (status IN ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'SUPPRESSED')),
  attempts          INT NOT NULL DEFAULT 0,
  max_attempts      INT NOT NULL DEFAULT 5,
  last_error        TEXT,
  next_attempt_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at           TIMESTAMPTZ,
  dedupe_key        TEXT UNIQUE
);

CREATE INDEX IF NOT EXISTS idx_outbox_pending
  ON public.notification_outbox(status, next_attempt_at)
  WHERE status IN ('PENDING', 'FAILED');

ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view notification outbox"
  ON public.notification_outbox FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid()));

-- =============================================================================
-- SECTION 3: NOTIFICATION MANAGEMENT RPCS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.register_device_token(
  p_device_token TEXT,
  p_platform TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.device_registrations (
    user_id,
    device_token,
    platform,
    is_active,
    updated_at
  )
  VALUES (
    v_user_id,
    p_device_token,
    UPPER(p_platform),
    TRUE,
    NOW()
  )
  ON CONFLICT (user_id, device_token)
  DO UPDATE SET
    is_active = TRUE,
    platform = UPPER(p_platform),
    updated_at = NOW();

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.unregister_device_token(p_device_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.device_registrations
  SET is_active = FALSE,
      updated_at = NOW()
  WHERE user_id = v_user_id AND device_token = p_device_token;

  RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: OPERATIONAL ATTENTION QUEUE RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_operational_attention_items()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'stuck_pickups', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'delivery_code', delivery_code,
          'origin_city', origin_city,
          'created_at', created_at,
          'issue', 'Awaiting pickup for over 4 hours'
        )
      )
      FROM public.shipments
      WHERE current_status = 'REQUESTED' AND created_at < NOW() - INTERVAL '4 hours'
    ),
    'unassigned_staged_parcels', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'delivery_code', s.delivery_code,
          'origin_city', s.origin_city,
          'staged_since', p.updated_at,
          'issue', 'Staged at origin hub over 6 hours without batch'
        )
      )
      FROM public.parcels p
      JOIN public.shipments s ON s.id = p.shipment_id
      WHERE p.current_parcel_state = 'ORIGIN_HUB_STAGED' AND p.updated_at < NOW() - INTERVAL '6 hours'
    ),
    'unreconciled_batches', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', id,
          'batch_reference', batch_reference,
          'destination_city', destination_city,
          'issue', 'Arrived at destination hub over 2 hours without reconciliation'
        )
      )
      FROM public.batches
      WHERE current_batch_state = 'DESTINATION_RECEIVED' AND updated_at < NOW() - INTERVAL '2 hours'
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 5: SYSTEM INTEGRITY VERIFICATION RPC (READ-ONLY)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.run_system_integrity_checks()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_admin RECORD;
  v_inconsistencies JSONB;
BEGIN
  SELECT * INTO v_admin FROM public.admins WHERE user_id = v_user_id;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Admin access required.' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'unpaid_delivered_shipments_count', (
      SELECT COUNT(*)
      FROM public.shipments s
      JOIN public.payment_obligations po ON po.shipment_id = s.id AND po.payer_party = 'RECEIVER'
      WHERE s.current_status = 'DELIVERED' AND po.expected_amount > 0 AND po.status != 'COLLECTED'
    ),
    'custody_state_mismatches_count', (
      SELECT COUNT(*)
      FROM public.parcels p
      JOIN public.shipments s ON s.id = p.shipment_id
      WHERE s.current_status = 'DELIVERED' AND p.current_custody_type != 'RECEIVER'
    ),
    'duplicate_active_batch_memberships_count', (
      SELECT COUNT(*)
      FROM (
        SELECT parcel_id
        FROM public.batch_memberships
        WHERE is_active = TRUE
        GROUP BY parcel_id
        HAVING COUNT(*) > 1
      ) sub
    )
  ) INTO v_inconsistencies;

  RETURN jsonb_build_object(
    'checked_at', NOW(),
    'inconsistencies', v_inconsistencies,
    'healthy', (
      (v_inconsistencies->>'unpaid_delivered_shipments_count')::int = 0 AND
      (v_inconsistencies->>'custody_state_mismatches_count')::int = 0 AND
      (v_inconsistencies->>'duplicate_active_batch_memberships_count')::int = 0
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_device_token(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_operational_attention_items() TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_system_integrity_checks() TO authenticated;
