-- =============================================================================
-- Cerelo V1 — Security Closure, Ownership Bypass Audit & PII Least Privilege
-- Version: 20260817000021
-- Description:
--   1. Replaces broad table SELECT RLS policies on shipments, customers, parcels,
--      payment_obligations, payment_collections, pickup_exceptions, delivery_attempts,
--      receiver_verifications, parcel_size_corrections, and operational_events.
--   2. Scopes customer and shipment PII visibility to active/assigned operational tasks only.
--   3. Adds record_failed_delivery_attempt RPC with strict destination hub and assigned ownership enforcement.
--   4. Hardens record_pickup_exception with strict origin hub and assigned ownership enforcement.
--   5. Hardens confirm_receiver_receipt with strict customer authentication, receiver identity checks,
--      search_path safety, and status invariants.
--   6. Introduces is_active_admin and is_active_personnel stable security helpers.
-- =============================================================================

-- =============================================================================
-- SECTION 1: STABLE SECURITY HELPER FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.is_active_admin(check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.admins WHERE user_id = check_user_id AND is_active = TRUE
    UNION ALL
    SELECT 1 FROM public.admin_users WHERE id = check_user_id AND is_active = TRUE
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public;

CREATE OR REPLACE FUNCTION public.is_active_personnel(check_user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.personnel
    WHERE user_id = check_user_id
      AND is_active = TRUE
      AND operating_hub_id IS NOT NULL
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public;

GRANT EXECUTE ON FUNCTION public.is_active_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_personnel(UUID) TO authenticated;

-- =============================================================================
-- SECTION 2: HARDENED OPERATIONAL RPCS
-- =============================================================================

-- 1. Hardened record_pickup_exception (Owner & Origin Hub Enforced)
CREATE OR REPLACE FUNCTION public.record_pickup_exception(
  p_shipment_id UUID,
  p_reason TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_exception_id UUID;
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

  -- Hub Scope Invariant
  IF v_shipment.origin_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Forbidden: Shipment origin does not match your assigned operating hub.' USING ERRCODE = '42501';
  END IF;

  -- Owner check: If claimed, MUST be assigned to caller
  IF v_shipment.assigned_pickup_personnel_id IS NOT NULL AND v_shipment.assigned_pickup_personnel_id != v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned pickup personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status NOT IN ('REQUESTED', 'PICKUP_IN_PROGRESS') THEN
    RAISE EXCEPTION 'Cannot record pickup exception for shipment in status %', v_shipment.current_status USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_reason)) NOT IN (
    'SENDER_UNAVAILABLE', 'UNACCEPTABLE_PARCEL',
    'PRICE_REJECTED', 'RECEIVER_VERIFICATION_FAILED',
    'PAYMENT_REFUSED', 'OTHER'
  ) THEN
    RAISE EXCEPTION 'Invalid exception reason: %', p_reason USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.pickup_exceptions (
    shipment_id,
    personnel_id,
    reason,
    notes
  )
  VALUES (
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_reason)),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_exception_id;

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
    'PICKUP_FAILED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'reason', UPPER(TRIM(p_reason)),
      'notes', p_notes,
      'personnel_id', v_personnel.id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'exception_id', v_exception_id,
    'reason', UPPER(TRIM(p_reason))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 2. Authoritative record_failed_delivery_attempt (Owner & Destination Hub Enforced)
CREATE OR REPLACE FUNCTION public.record_failed_delivery_attempt(
  p_shipment_id UUID,
  p_reason TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_shipment RECORD;
  v_attempt_id UUID;
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

  -- Hub Scope Invariant
  IF v_shipment.destination_hub_id != v_personnel.operating_hub_id THEN
    RAISE EXCEPTION 'Forbidden: Shipment destination does not match your assigned operating hub.' USING ERRCODE = '42501';
  END IF;

  -- Owner check: Must be assigned delivery personnel
  IF v_shipment.assigned_delivery_personnel_id IS DISTINCT FROM v_personnel.id THEN
    RAISE EXCEPTION 'Forbidden: You are not the assigned delivery personnel for this shipment.' USING ERRCODE = '42501';
  END IF;

  IF v_shipment.current_status != 'OUT_FOR_DELIVERY' THEN
    RAISE EXCEPTION 'Shipment must be OUT_FOR_DELIVERY to record failed delivery attempt (current: %)', v_shipment.current_status
      USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_reason)) NOT IN (
    'RECEIVER_UNAVAILABLE', 'RECEIVER_REFUSED',
    'PAYMENT_REFUSED', 'WRONG_ADDRESS', 'DAMAGED'
  ) THEN
    RAISE EXCEPTION 'Invalid delivery attempt outcome reason: %', p_reason USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.delivery_attempts (
    shipment_id,
    attempted_by_personnel_id,
    outcome,
    notes
  )
  VALUES (
    p_shipment_id,
    v_personnel.id,
    UPPER(TRIM(p_reason)),
    NULLIF(TRIM(p_notes), '')
  )
  RETURNING id INTO v_attempt_id;

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
    'SHIPMENT_DELIVERY_FAILED',
    v_personnel.id,
    'PERSONNEL',
    v_personnel.operating_hub_id,
    jsonb_build_object(
      'outcome', UPPER(TRIM(p_reason)),
      'notes', p_notes,
      'attempted_by', v_personnel.full_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'attempt_id', v_attempt_id,
    'outcome', UPPER(TRIM(p_reason))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- 3. Hardened Customer Receiver Confirmation (Authoritative Low-Trust Acknowledgment)
CREATE OR REPLACE FUNCTION public.confirm_receiver_receipt(p_shipment_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_customer RECORD;
  v_shipment RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated. Customer login required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer account required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.' USING ERRCODE = 'P0002';
  END IF;

  -- Receiver Authorization Check (NULL-safe positive match)
  IF NOT (
    (v_shipment.receiver_customer_id IS NOT NULL AND v_shipment.receiver_customer_id = v_customer.id)
    OR (v_shipment.receiver_phone_snapshot IS NOT NULL AND v_shipment.receiver_phone_snapshot = v_customer.phone_number)
  ) THEN
    RAISE EXCEPTION 'Forbidden: You are not the receiver of this shipment.' USING ERRCODE = '42501';
  END IF;

  -- Invariant: Authoritative physical completion is done by Personnel mark_delivered.
  -- Customer receipt confirmation is only valid on ALREADY DELIVERED shipments.
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;

-- =============================================================================
-- SECTION 3: PII LEAST-PRIVILEGE ROW LEVEL SECURITY REFACTOR
-- =============================================================================

-- 1. public.customers
DROP POLICY IF EXISTS "personnel: scoped customer read for hub tasks" ON public.customers;
DROP POLICY IF EXISTS "customers: view own profile" ON public.customers;
DROP POLICY IF EXISTS "customers: select own profile" ON public.customers;
DROP POLICY IF EXISTS "customers: admin full read" ON public.customers;
DROP POLICY IF EXISTS "customers: personnel active task read" ON public.customers;
DROP POLICY IF EXISTS "admin: full customer read access" ON public.customers;

CREATE POLICY "customers: select own profile"
  ON public.customers FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "customers: admin full read"
  ON public.customers FOR SELECT
  USING (public.is_active_admin());

CREATE POLICY "customers: personnel active task read"
  ON public.customers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.personnel p
      JOIN public.shipments s ON (s.sender_customer_id = customers.id OR s.receiver_customer_id = customers.id)
      WHERE p.user_id = auth.uid()
        AND p.is_active = TRUE
        AND p.operating_hub_id IS NOT NULL
        AND (
          s.assigned_pickup_personnel_id = p.id
          OR s.assigned_delivery_personnel_id = p.id
          OR (s.origin_hub_id = p.operating_hub_id AND s.current_status = 'REQUESTED' AND s.assigned_pickup_personnel_id IS NULL)
          OR (s.destination_hub_id = p.operating_hub_id AND s.current_status = 'ARRIVED_DESTINATION' AND s.assigned_delivery_personnel_id IS NULL)
        )
    )
  );

-- 2. public.shipments
DROP POLICY IF EXISTS "shipments: view own shipments" ON public.shipments;
DROP POLICY IF EXISTS "shipments: customer own shipments" ON public.shipments;
DROP POLICY IF EXISTS "shipments: admin full read" ON public.shipments;
DROP POLICY IF EXISTS "shipments: personnel scoped hub read" ON public.shipments;

CREATE POLICY "shipments: customer own shipments"
  ON public.shipments FOR SELECT
  USING (sender_customer_id = auth.uid() OR receiver_customer_id = auth.uid());

CREATE POLICY "shipments: admin full read"
  ON public.shipments FOR SELECT
  USING (public.is_active_admin());

CREATE POLICY "shipments: personnel scoped hub read"
  ON public.shipments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.personnel p
      WHERE p.user_id = auth.uid()
        AND p.is_active = TRUE
        AND p.operating_hub_id IS NOT NULL
        AND (
          shipments.assigned_pickup_personnel_id = p.id
          OR shipments.assigned_delivery_personnel_id = p.id
          OR (shipments.origin_hub_id = p.operating_hub_id AND shipments.current_status = 'REQUESTED' AND shipments.assigned_pickup_personnel_id IS NULL)
          OR (shipments.destination_hub_id = p.operating_hub_id AND shipments.current_status = 'ARRIVED_DESTINATION' AND shipments.assigned_delivery_personnel_id IS NULL)
          OR (p.operating_hub_id IN (shipments.origin_hub_id, shipments.destination_hub_id) AND shipments.current_status IN ('AT_ORIGIN_HUB', 'BATCHED', 'IN_TRANSIT'))
        )
    )
  );

-- 3. public.parcels
DROP POLICY IF EXISTS "parcels: view parcel of own shipment" ON public.parcels;
DROP POLICY IF EXISTS "parcels: scoped read" ON public.parcels;

CREATE POLICY "parcels: scoped read"
  ON public.parcels FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = parcels.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR public.is_active_admin()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (
                s.assigned_pickup_personnel_id = p.id
                OR s.assigned_delivery_personnel_id = p.id
                OR (s.origin_hub_id = p.operating_hub_id AND s.current_status = 'REQUESTED' AND s.assigned_pickup_personnel_id IS NULL)
                OR (s.destination_hub_id = p.operating_hub_id AND s.current_status = 'ARRIVED_DESTINATION' AND s.assigned_delivery_personnel_id IS NULL)
                OR (p.operating_hub_id IN (s.origin_hub_id, s.destination_hub_id) AND s.current_status IN ('AT_ORIGIN_HUB', 'BATCHED', 'IN_TRANSIT'))
              )
          )
        )
    )
  );

-- 4. public.payment_obligations
DROP POLICY IF EXISTS "payment_obligations: view obligations of own shipment" ON public.payment_obligations;
DROP POLICY IF EXISTS "payment_obligations: scoped read" ON public.payment_obligations;

CREATE POLICY "payment_obligations: scoped read"
  ON public.payment_obligations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = payment_obligations.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR public.is_active_admin()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (
                s.assigned_pickup_personnel_id = p.id
                OR s.assigned_delivery_personnel_id = p.id
                OR (s.origin_hub_id = p.operating_hub_id AND s.current_status = 'REQUESTED' AND s.assigned_pickup_personnel_id IS NULL)
                OR (s.destination_hub_id = p.operating_hub_id AND s.current_status = 'ARRIVED_DESTINATION' AND s.assigned_delivery_personnel_id IS NULL)
                OR (p.operating_hub_id IN (s.origin_hub_id, s.destination_hub_id) AND s.current_status IN ('AT_ORIGIN_HUB', 'BATCHED', 'IN_TRANSIT'))
              )
          )
        )
    )
  );

-- 5. public.payment_collections
DROP POLICY IF EXISTS "payment_collections: personnel read" ON public.payment_collections;
DROP POLICY IF EXISTS "payment_collections: scoped read" ON public.payment_collections;

CREATE POLICY "payment_collections: scoped read"
  ON public.payment_collections FOR SELECT
  USING (
    public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.payment_obligations po
      JOIN public.shipments s ON s.id = po.shipment_id
      WHERE po.id = payment_collections.payment_obligation_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (s.assigned_pickup_personnel_id = p.id OR s.assigned_delivery_personnel_id = p.id)
          )
        )
    )
  );

-- 6. public.pickup_exceptions
DROP POLICY IF EXISTS "pickup_exceptions: personnel read" ON public.pickup_exceptions;
DROP POLICY IF EXISTS "pickup_exceptions: scoped read" ON public.pickup_exceptions;

CREATE POLICY "pickup_exceptions: scoped read"
  ON public.pickup_exceptions FOR SELECT
  USING (
    public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = pickup_exceptions.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (
                s.assigned_pickup_personnel_id = p.id
                OR (s.origin_hub_id = p.operating_hub_id AND s.current_status = 'REQUESTED')
              )
          )
        )
    )
  );

-- 7. public.delivery_attempts
DROP POLICY IF EXISTS "Personnel can view delivery attempts" ON public.delivery_attempts;
DROP POLICY IF EXISTS "delivery_attempts: scoped read" ON public.delivery_attempts;

CREATE POLICY "delivery_attempts: scoped read"
  ON public.delivery_attempts FOR SELECT
  USING (
    public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = delivery_attempts.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (
                s.assigned_delivery_personnel_id = p.id
                OR (s.destination_hub_id = p.operating_hub_id AND s.current_status = 'ARRIVED_DESTINATION')
              )
          )
        )
    )
  );

-- 8. public.receiver_verifications
DROP POLICY IF EXISTS "receiver_verifications: personnel read" ON public.receiver_verifications;
DROP POLICY IF EXISTS "receiver_verifications: scoped read" ON public.receiver_verifications;

CREATE POLICY "receiver_verifications: scoped read"
  ON public.receiver_verifications FOR SELECT
  USING (
    public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = receiver_verifications.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND s.assigned_pickup_personnel_id = p.id
          )
        )
    )
  );

-- 9. public.parcel_size_corrections
DROP POLICY IF EXISTS "parcel_size_corrections: personnel read" ON public.parcel_size_corrections;
DROP POLICY IF EXISTS "parcel_size_corrections: scoped read" ON public.parcel_size_corrections;

CREATE POLICY "parcel_size_corrections: scoped read"
  ON public.parcel_size_corrections FOR SELECT
  USING (
    public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = parcel_size_corrections.shipment_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND s.assigned_pickup_personnel_id = p.id
          )
        )
    )
  );

-- 10. public.operational_events
DROP POLICY IF EXISTS "operational_events: view events of own shipment" ON public.operational_events;
DROP POLICY IF EXISTS "operational_events: scoped read" ON public.operational_events;

CREATE POLICY "operational_events: scoped read"
  ON public.operational_events FOR SELECT
  USING (
    actor_id = auth.uid()
    OR public.is_active_admin()
    OR EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = operational_events.aggregate_id
        AND (
          s.sender_customer_id = auth.uid()
          OR s.receiver_customer_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.personnel p
            WHERE p.user_id = auth.uid()
              AND p.is_active = TRUE
              AND p.operating_hub_id IS NOT NULL
              AND (
                s.assigned_pickup_personnel_id = p.id
                OR s.assigned_delivery_personnel_id = p.id
                OR (s.origin_hub_id = p.operating_hub_id AND s.current_status = 'REQUESTED')
                OR (s.destination_hub_id = p.operating_hub_id AND s.current_status = 'ARRIVED_DESTINATION')
              )
          )
        )
    )
  );

-- =============================================================================
-- SECTION 4: GRANTS
-- =============================================================================

GRANT EXECUTE ON FUNCTION public.record_failed_delivery_attempt(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_pickup_exception(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_receiver_receipt(UUID) TO authenticated;
