-- =============================================================================
-- Cerelo V1 — Batch Management & Middle-Mile Operations Migration
-- Version: 20260817000007
-- Description: Consolidation domain: Batches, Batch Memberships, Transit Runs,
--              Transport Partners, Batch QR, and Atomic Onboarding transaction.
-- =============================================================================

-- =============================================================================
-- SECTION 1: TRANSPORT PARTNERS & TRANSIT RUNS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.transport_partners (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           TEXT NOT NULL,
  contact_phone  TEXT,
  vehicle_type   TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed standard commercial transport lines for Kano ↔ Katsina
INSERT INTO public.transport_partners (name, contact_phone, vehicle_type, is_active)
VALUES
  ('Kano-Katsina Commercial Transit Line', '+2348030001111', 'HiAce Commercial Bus', TRUE),
  ('Kwari Market Express Line', '+2348030002222', 'Transit Minivan', TRUE)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS public.transit_runs (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  corridor_id             UUID NOT NULL REFERENCES public.corridors(id),
  transport_partner_id    UUID REFERENCES public.transport_partners(id),
  driver_name             TEXT,
  driver_phone            TEXT,
  vehicle_plate_number    TEXT,
  agreed_cost_amount      INT NOT NULL DEFAULT 0 CHECK (agreed_cost_amount >= 0),
  scheduled_departure_at  TIMESTAMPTZ,
  actual_departure_at     TIMESTAMPTZ,
  actual_arrival_at       TIMESTAMPTZ,
  status                  TEXT NOT NULL DEFAULT 'SCHEDULED'
                            CHECK (status IN ('SCHEDULED', 'DEPARTED', 'ARRIVED', 'CANCELLED')),
  created_by_personnel_id UUID REFERENCES public.personnel(id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SECTION 2: BATCHES & BATCH MEMBERSHIPS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.generate_batch_reference()
RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_seg1 TEXT := '';
  v_seg2 TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..4 LOOP
    v_seg1 := v_seg1 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    v_seg2 := v_seg2 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
  END LOOP;
  RETURN 'BAT-' || v_seg1 || '-' || v_seg2;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION public.generate_batch_qr_token()
RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  v_seg1 TEXT := '';
  v_seg2 TEXT := '';
  v_seg3 TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..4 LOOP
    v_seg1 := v_seg1 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    v_seg2 := v_seg2 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    v_seg3 := v_seg3 || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
  END LOOP;
  RETURN 'BQR-' || v_seg1 || '-' || v_seg2 || '-' || v_seg3;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TABLE IF NOT EXISTS public.batches (
  id                         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  batch_reference            TEXT NOT NULL UNIQUE,
  corridor_id                UUID NOT NULL REFERENCES public.corridors(id),
  origin_hub_id              UUID NOT NULL REFERENCES public.operating_hubs(id),
  destination_hub_id         UUID NOT NULL REFERENCES public.operating_hubs(id),
  origin_city                TEXT,
  destination_city           TEXT,
  batch_qr_token             TEXT UNIQUE,
  current_batch_state        TEXT NOT NULL DEFAULT 'DRAFT'
                               CHECK (current_batch_state IN (
                                 'DRAFT', 'CONFIRMED', 'ONBOARDED', 'DESTINATION_RECEIVED',
                                 'RECONCILING', 'RECONCILED', 'CLOSED', 'CANCELLED'
                               )),
  transit_run_id             UUID REFERENCES public.transit_runs(id),
  manifest_parcel_count      INT NOT NULL DEFAULT 0 CHECK (manifest_parcel_count >= 0),
  created_by_personnel_id    UUID NOT NULL REFERENCES public.personnel(id),
  confirmed_by_personnel_id  UUID REFERENCES public.personnel(id),
  confirmed_at               TIMESTAMPTZ,
  onboarded_by_personnel_id  UUID REFERENCES public.personnel(id),
  onboarded_at               TIMESTAMPTZ,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.batch_memberships (
  id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  batch_id               UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
  parcel_id              UUID NOT NULL REFERENCES public.parcels(id) ON DELETE CASCADE,
  added_by_personnel_id  UUID NOT NULL REFERENCES public.personnel(id),
  added_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  removed_at             TIMESTAMPTZ,
  removed_by_personnel_id UUID REFERENCES public.personnel(id),
  removal_reason         TEXT
);

-- Invariant: One active batch membership per parcel
CREATE UNIQUE INDEX IF NOT EXISTS idx_batch_memberships_active_parcel
  ON public.batch_memberships(parcel_id)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_batch_memberships_batch ON public.batch_memberships(batch_id, is_active);
CREATE INDEX IF NOT EXISTS idx_batches_state ON public.batches(current_batch_state);
CREATE INDEX IF NOT EXISTS idx_batches_origin ON public.batches(origin_hub_id, current_batch_state);
CREATE INDEX IF NOT EXISTS idx_batches_qr ON public.batches(batch_qr_token);

-- RLS
ALTER TABLE public.transport_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transit_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batch_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Personnel can view transport partners"
  ON public.transport_partners FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

CREATE POLICY "Personnel can view transit runs"
  ON public.transit_runs FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

CREATE POLICY "Personnel can view batches"
  ON public.batches FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

CREATE POLICY "Personnel can view batch memberships"
  ON public.batch_memberships FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.personnel WHERE user_id = auth.uid() AND is_active = TRUE));

-- =============================================================================
-- SECTION 3: BATCH MANAGEMENT RPCS
-- =============================================================================

-- 1. Create Batch RPC
CREATE OR REPLACE FUNCTION public.create_batch(
  p_origin_hub_id UUID,
  p_destination_hub_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_corridor RECORD;
  v_ref TEXT;
  v_batch_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_corridor
  FROM public.corridors
  WHERE origin_hub_id = p_origin_hub_id AND destination_hub_id = p_destination_hub_id AND is_active = TRUE;

  IF v_corridor IS NULL THEN
    RAISE EXCEPTION 'No active corridor found between origin and destination hubs.' USING ERRCODE = 'P0002';
  END IF;

  v_ref := public.generate_batch_reference();

  INSERT INTO public.batches (
    batch_reference,
    corridor_id,
    origin_hub_id,
    destination_hub_id,
    current_batch_state,
    created_by_personnel_id
  )
  VALUES (
    v_ref,
    v_corridor.id,
    p_origin_hub_id,
    p_destination_hub_id,
    'DRAFT',
    v_personnel.id
  )
  RETURNING id INTO v_batch_id;

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
    v_batch_id,
    'BATCH_CREATED',
    v_personnel.id,
    'PERSONNEL',
    p_origin_hub_id,
    jsonb_build_object('batch_reference', v_ref, 'corridor_code', v_corridor.code)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', v_batch_id,
    'batch_reference', v_ref,
    'corridor_code', v_corridor.code,
    'status', 'DRAFT',
    'manifest_parcel_count', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Add Parcel to Batch RPC
CREATE OR REPLACE FUNCTION public.add_parcel_to_batch(
  p_batch_id UUID,
  p_parcel_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Cannot modify non-draft batch (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id;
  IF v_parcel IS NULL THEN
    RAISE EXCEPTION 'Parcel not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_parcel.current_parcel_state NOT IN ('ORIGIN_HUB_STAGED', 'BATCH_LOCKED') THEN
    RAISE EXCEPTION 'Parcel is not staged at origin hub (current state: %)', v_parcel.current_parcel_state
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_shipment FROM public.shipments WHERE id = v_parcel.shipment_id;
  IF v_shipment.corridor_id != v_batch.corridor_id THEN
    RAISE EXCEPTION 'Parcel destination corridor does not match batch corridor.' USING ERRCODE = '23514';
  END IF;

  -- Check if already in this batch
  IF EXISTS (SELECT 1 FROM public.batch_memberships WHERE batch_id = p_batch_id AND parcel_id = p_parcel_id AND is_active = TRUE) THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_added', true,
      'batch_id', p_batch_id,
      'parcel_id', p_parcel_id,
      'manifest_parcel_count', v_batch.manifest_parcel_count
    );
  END IF;

  -- Invariant: One active batch membership per parcel
  IF EXISTS (SELECT 1 FROM public.batch_memberships WHERE parcel_id = p_parcel_id AND is_active = TRUE) THEN
    RAISE EXCEPTION 'Parcel is already assigned to another active batch.' USING ERRCODE = '23505';
  END IF;

  -- Insert Membership
  INSERT INTO public.batch_memberships (
    batch_id,
    parcel_id,
    added_by_personnel_id
  )
  VALUES (
    p_batch_id,
    p_parcel_id,
    v_personnel.id
  );

  UPDATE public.parcels
  SET current_parcel_state = 'BATCH_LOCKED'
  WHERE id = p_parcel_id;

  UPDATE public.batches
  SET manifest_parcel_count = manifest_parcel_count + 1
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
    'PARCEL_ADDED_TO_BATCH',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object('parcel_id', p_parcel_id, 'delivery_code', v_shipment.delivery_code)
  );

  RETURN jsonb_build_object(
    'success', true,
    'already_added', false,
    'batch_id', p_batch_id,
    'parcel_id', p_parcel_id,
    'manifest_parcel_count', v_batch.manifest_parcel_count + 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Remove Parcel from Draft Batch RPC
CREATE OR REPLACE FUNCTION public.remove_parcel_from_draft_batch(
  p_batch_id UUID,
  p_parcel_id UUID,
  p_reason TEXT DEFAULT 'Removed by personnel before confirmation'
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

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Cannot modify non-draft batch (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.batch_memberships
  SET is_active = FALSE,
      removed_at = NOW(),
      removed_by_personnel_id = v_personnel.id,
      removal_reason = p_reason
  WHERE batch_id = p_batch_id AND parcel_id = p_parcel_id AND is_active = TRUE;

  UPDATE public.parcels
  SET current_parcel_state = 'ORIGIN_HUB_STAGED'
  WHERE id = p_parcel_id;

  UPDATE public.batches
  SET manifest_parcel_count = GREATEST(0, manifest_parcel_count - 1)
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
    'PARCEL_REMOVED_FROM_BATCH',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object('parcel_id', p_parcel_id, 'reason', p_reason)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'parcel_id', p_parcel_id,
    'manifest_parcel_count', GREATEST(0, v_batch.manifest_parcel_count - 1)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Confirm Batch RPC
CREATE OR REPLACE FUNCTION public.confirm_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_active_count INT;
  v_qr_token TEXT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.current_batch_state = 'CONFIRMED' THEN
    RETURN jsonb_build_object(
      'success', true,
      'batch_id', p_batch_id,
      'batch_reference', v_batch.batch_reference,
      'batch_qr_token', v_batch.batch_qr_token,
      'status', 'CONFIRMED',
      'manifest_parcel_count', v_batch.manifest_parcel_count,
      'already_confirmed', true
    );
  END IF;

  IF v_batch.current_batch_state != 'DRAFT' THEN
    RAISE EXCEPTION 'Only draft batches can be confirmed (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  SELECT COUNT(*) INTO v_active_count
  FROM public.batch_memberships
  WHERE batch_id = p_batch_id AND is_active = TRUE;

  IF v_active_count = 0 THEN
    RAISE EXCEPTION 'Cannot confirm empty batch. Add at least one parcel.' USING ERRCODE = '23514';
  END IF;

  v_qr_token := public.generate_batch_qr_token();

  UPDATE public.batches
  SET current_batch_state = 'CONFIRMED',
      batch_qr_token = v_qr_token,
      manifest_parcel_count = v_active_count,
      confirmed_by_personnel_id = v_personnel.id,
      confirmed_at = NOW()
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
    'BATCH_CONFIRMED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object('parcel_count', v_active_count, 'batch_qr_token', v_qr_token)
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'batch_reference', v_batch.batch_reference,
    'batch_qr_token', v_qr_token,
    'status', 'CONFIRMED',
    'manifest_parcel_count', v_active_count,
    'already_confirmed', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Set Batch Transport Arrangement RPC
CREATE OR REPLACE FUNCTION public.set_batch_transport_arrangement(
  p_batch_id UUID,
  p_provider_name TEXT,
  p_driver_name TEXT DEFAULT NULL,
  p_driver_phone TEXT DEFAULT NULL,
  p_vehicle_plate TEXT DEFAULT NULL,
  p_agreed_cost_amount INT DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_run_id UUID;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_batch.current_batch_state NOT IN ('DRAFT', 'CONFIRMED') THEN
    RAISE EXCEPTION 'Cannot alter transport on departed or completed batch.' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.transit_runs (
    corridor_id,
    driver_name,
    driver_phone,
    vehicle_plate_number,
    agreed_cost_amount,
    created_by_personnel_id
  )
  VALUES (
    v_batch.corridor_id,
    p_driver_name,
    p_driver_phone,
    p_vehicle_plate,
    COALESCE(p_agreed_cost_amount, 0),
    v_personnel.id
  )
  RETURNING id INTO v_run_id;

  UPDATE public.batches
  SET transit_run_id = v_run_id
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
    'TRANSPORT_ASSIGNED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object(
      'transit_run_id', v_run_id,
      'provider_name', p_provider_name,
      'driver_name', p_driver_name,
      'agreed_cost_amount', p_agreed_cost_amount
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'transit_run_id', v_run_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Atomic Batch Onboarding RPC (Transitions Batch, Parcels, and Shipments to IN_TRANSIT)
CREATE OR REPLACE FUNCTION public.onboard_batch(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_parcel RECORD;
  v_shipment RECORD;
BEGIN
  -- 1. Security Check: Active Personnel
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Validate Batch
  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
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

  -- 4. Atomic State Updates: All Included Parcels and Shipments
  FOR v_parcel IN
    SELECT p.*, bm.id as membership_id
    FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'CORRIDOR_TRANSIT',
        current_custody_type = 'TRANSIT_PARTNER'
    WHERE id = v_parcel.id;

    UPDATE public.shipments
    SET current_status = 'IN_TRANSIT'
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
      'CORRIDOR_TRANSIT_STARTED',
      v_personnel.id,
      'PERSONNEL',
      v_batch.origin_hub_id,
      jsonb_build_object('batch_id', p_batch_id, 'batch_reference', v_batch.batch_reference)
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
      v_batch.origin_hub_id,
      jsonb_build_object(
        'from_custody', 'HUB',
        'to_custody', 'TRANSIT_PARTNER',
        'batch_id', p_batch_id
      )
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
      v_parcel.shipment_id,
      'SHIPMENT_IN_TRANSIT',
      v_personnel.id,
      'PERSONNEL',
      v_batch.origin_hub_id,
      jsonb_build_object('status', 'IN_TRANSIT')
    );
  END LOOP;

  -- 5. Batch Event
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
    'BATCH_ONBOARDED',
    v_personnel.id,
    'PERSONNEL',
    v_batch.origin_hub_id,
    jsonb_build_object(
      'batch_reference', v_batch.batch_reference,
      'transit_run_id', v_batch.transit_run_id,
      'parcel_count', v_batch.manifest_parcel_count
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'status', 'ONBOARDED',
    'already_onboarded', false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECTION 4: READ MODEL RPCS
-- =============================================================================

-- Query Batches list by state
CREATE OR REPLACE FUNCTION public.get_personnel_batches(p_status TEXT DEFAULT NULL)
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
      'id', b.id,
      'batch_reference', b.batch_reference,
      'batch_qr_token', b.batch_qr_token,
      'current_batch_state', b.current_batch_state,
      'corridor_code', c.code,
      'origin_city', oc.name,
      'destination_city', dc.name,
      'manifest_parcel_count', b.manifest_parcel_count,
      'confirmed_at', b.confirmed_at,
      'onboarded_at', b.onboarded_at,
      'created_at', b.created_at
    ) ORDER BY b.created_at DESC
  ) INTO v_result
  FROM public.batches b
  JOIN public.corridors c ON c.id = b.corridor_id
  JOIN public.cities oc ON oc.id = c.origin_city_id
  JOIN public.cities dc ON dc.id = c.destination_city_id
  WHERE (p_status IS NULL OR b.current_batch_state = UPPER(p_status));

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Query Batch Manifest details
CREATE OR REPLACE FUNCTION public.get_batch_manifest(p_batch_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_corridor RECORD;
  v_origin_city RECORD;
  v_destination_city RECORD;
  v_transit_run RECORD;
  v_parcels JSONB;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
  IF v_batch IS NULL THEN
    RAISE EXCEPTION 'Batch not found.' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_corridor FROM public.corridors WHERE id = v_batch.corridor_id;
  SELECT * INTO v_origin_city FROM public.cities WHERE id = v_corridor.origin_city_id;
  SELECT * INTO v_destination_city FROM public.cities WHERE id = v_corridor.destination_city_id;
  SELECT * INTO v_transit_run FROM public.transit_runs WHERE id = v_batch.transit_run_id;

  SELECT jsonb_agg(
    jsonb_build_object(
      'parcel_id', p.id,
      'shipment_id', s.id,
      'delivery_code', s.delivery_code,
      'parcel_qr_token', p.parcel_qr_token,
      'origin_city', v_origin_city.name,
      'destination_city', v_destination_city.name,
      'confirmed_size_code', COALESCE(cst.code, pst.code),
      'confirmed_size_name', COALESCE(cst.name, pst.name),
      'category_description', p.category_description,
      'current_parcel_state', p.current_parcel_state,
      'added_at', bm.added_at
    ) ORDER BY bm.added_at ASC
  ) INTO v_parcels
  FROM public.batch_memberships bm
  JOIN public.parcels p ON p.id = bm.parcel_id
  JOIN public.shipments s ON s.id = p.shipment_id
  JOIN public.parcel_size_tiers pst ON pst.id = p.sender_declared_size_id
  LEFT JOIN public.parcel_size_tiers cst ON cst.id = p.confirmed_size_id
  WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE;

  RETURN jsonb_build_object(
    'batch_id', v_batch.id,
    'batch_reference', v_batch.batch_reference,
    'batch_qr_token', v_batch.batch_qr_token,
    'current_batch_state', v_batch.current_batch_state,
    'corridor_code', v_corridor.code,
    'origin_city', v_origin_city.name,
    'destination_city', v_destination_city.name,
    'manifest_parcel_count', v_batch.manifest_parcel_count,
    'driver_name', v_transit_run.driver_name,
    'driver_phone', v_transit_run.driver_phone,
    'vehicle_plate_number', v_transit_run.vehicle_plate_number,
    'agreed_cost_amount', COALESCE(v_transit_run.agreed_cost_amount, 0),
    'confirmed_at', v_batch.confirmed_at,
    'onboarded_at', v_batch.onboarded_at,
    'parcels', COALESCE(v_parcels, '[]'::jsonb)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resolve Batch by Batch QR
CREATE OR REPLACE FUNCTION public.resolve_batch_by_qr(p_batch_qr_token TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_personnel RECORD;
  v_batch RECORD;
  v_clean_token TEXT;
BEGIN
  SELECT * INTO v_personnel FROM public.personnel WHERE user_id = v_user_id AND is_active = TRUE;
  IF v_personnel IS NULL THEN
    RAISE EXCEPTION 'Active personnel access required.' USING ERRCODE = '42501';
  END IF;

  v_clean_token := UPPER(TRIM(p_batch_qr_token));
  IF v_clean_token LIKE 'CERELO://BATCH/%' THEN
    v_clean_token := substr(v_clean_token, 16);
  END IF;

  SELECT * INTO v_batch FROM public.batches WHERE batch_qr_token = v_clean_token;
  IF v_batch IS NULL THEN
    RETURN jsonb_build_object('is_valid', false, 'error', 'BATCH_NOT_FOUND');
  END IF;

  RETURN public.get_batch_manifest(v_batch.id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.create_batch(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_parcel_to_batch(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_parcel_from_draft_batch(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_batch_transport_arrangement(UUID, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.onboard_batch(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_personnel_batches(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_batch_manifest(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_batch_by_qr(TEXT) TO authenticated;
