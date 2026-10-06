-- =============================================================================
-- Cerelo V1 — Shipment Request Domain & Configuration Migration
-- Version: 20260817000003
-- Description: Core logistics domain tables (cities, corridors, parcel_size_tiers,
--              pricing_rules, shipments, parcels, payment_obligations, operational_events)
--              and atomic create_shipment_request / pricing RPC functions.
-- =============================================================================

-- =============================================================================
-- SECTION 1: CITIES & OPERATING HUBS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.cities (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL UNIQUE,
  code       TEXT NOT NULL UNIQUE,  -- 'KAN', 'KAT'
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.operating_hubs (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  city_id    UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  code       TEXT NOT NULL UNIQUE,  -- 'KAN-HUB-01', 'KAT-HUB-01'
  address    TEXT NOT NULL,
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Link operating_hub_id in personnel table to operating_hubs
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_personnel_operating_hub'
  ) THEN
    ALTER TABLE public.personnel
      ADD CONSTRAINT fk_personnel_operating_hub
      FOREIGN KEY (operating_hub_id) REFERENCES public.operating_hubs(id);
  END IF;
END $$;

-- =============================================================================
-- SECTION 2: CORRIDORS (Directional)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.corridors (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  origin_city_id      UUID NOT NULL REFERENCES public.cities(id),
  destination_city_id UUID NOT NULL REFERENCES public.cities(id),
  origin_hub_id       UUID REFERENCES public.operating_hubs(id),
  destination_hub_id  UUID REFERENCES public.operating_hubs(id),
  code                TEXT NOT NULL UNIQUE,  -- 'KAN-KAT', 'KAT-KAN'
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT check_different_cities CHECK (origin_city_id != destination_city_id)
);

-- =============================================================================
-- SECTION 3: PARCEL SIZE TIERS & PRICING RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.parcel_size_tiers (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code          TEXT NOT NULL UNIQUE,  -- 'SMALL', 'MEDIUM', 'LARGE'
  name          TEXT NOT NULL,
  description   TEXT,
  max_weight_kg NUMERIC NOT NULL DEFAULT 5.0,
  display_order INT NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pricing_rules (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  corridor_id         UUID NOT NULL REFERENCES public.corridors(id) ON DELETE CASCADE,
  parcel_size_tier_id UUID NOT NULL REFERENCES public.parcel_size_tiers(id) ON DELETE CASCADE,
  base_price_amount   INT NOT NULL CHECK (base_price_amount >= 0),  -- in Kobo (e.g. 300000 = ₦3,000)
  currency            TEXT NOT NULL DEFAULT 'NGN',
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_corridor_size_pricing UNIQUE(corridor_id, parcel_size_tier_id)
);

-- Backward-compatible corridor_pricing_rules view
CREATE OR REPLACE VIEW public.corridor_pricing_rules AS
  SELECT
    id,
    corridor_id,
    parcel_size_tier_id,
    base_price_amount,
    currency,
    is_active,
    created_at
  FROM public.pricing_rules;

GRANT SELECT ON public.corridor_pricing_rules TO authenticated;

-- =============================================================================
-- SECTION 4: SHIPMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.shipments (
  id                                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_code                      TEXT NOT NULL UNIQUE,  -- CRL-XXXX-XXXX
  sender_customer_id                 UUID NOT NULL REFERENCES public.customers(id),
  receiver_customer_id               UUID REFERENCES public.customers(id),
  corridor_id                        UUID NOT NULL REFERENCES public.corridors(id),
  origin_city                        TEXT NOT NULL,
  destination_city                   TEXT NOT NULL,
  origin_hub_id                      UUID REFERENCES public.operating_hubs(id),
  destination_hub_id                 UUID REFERENCES public.operating_hubs(id),

  -- Snapshots (immutable historical agreement)
  sender_name_snapshot               TEXT NOT NULL,
  sender_phone_snapshot              TEXT NOT NULL,
  sender_pickup_address_snapshot     TEXT NOT NULL,
  receiver_name_snapshot             TEXT NOT NULL,
  receiver_phone_snapshot            TEXT NOT NULL,
  receiver_delivery_address_snapshot TEXT NOT NULL,
  delivery_instructions              TEXT,
  landmark                           TEXT,

  -- Commercial / Pricing Snapshots
  quoted_price_amount                INT NOT NULL CHECK (quoted_price_amount >= 0),
  final_price_amount                 INT NOT NULL CHECK (final_price_amount >= 0),
  currency                           TEXT NOT NULL DEFAULT 'NGN',
  payment_mode                       TEXT NOT NULL
                                       CHECK (payment_mode IN ('SENDER_PAYS', 'RECEIVER_PAYS', 'SPLIT_PAYMENT')),

  -- Operational State Machine
  current_status                     TEXT NOT NULL DEFAULT 'REQUESTED'
                                       CHECK (current_status IN (
                                         'REQUESTED', 'PICKUP_IN_PROGRESS', 'PARCEL_CONFIRMED',
                                         'AT_ORIGIN_HUB', 'BATCHED', 'IN_TRANSIT',
                                         'ARRIVED_DESTINATION', 'OUT_FOR_DELIVERY',
                                         'DELIVERED', 'DELIVERY_FAILED', 'CANCELLED'
                                       )),
  idempotency_key                    TEXT UNIQUE,

  -- Delivery Completion
  delivered_at                       TIMESTAMPTZ,
  delivered_by_personnel_id          UUID REFERENCES public.personnel(id),
  receiver_confirmed_at              TIMESTAMPTZ,
  receiver_confirmed_by_customer_id  UUID REFERENCES public.customers(id),

  created_at                         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SECTION 5: PARCELS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.parcels (
  id                         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id                UUID NOT NULL UNIQUE REFERENCES public.shipments(id) ON DELETE CASCADE,
  sender_declared_size_id    UUID NOT NULL REFERENCES public.parcel_size_tiers(id),
  confirmed_size_id          UUID REFERENCES public.parcel_size_tiers(id),
  category_description       TEXT NOT NULL,
  parcel_qr_token            TEXT UNIQUE,
  qr_label_url               TEXT,
  current_parcel_state       TEXT NOT NULL DEFAULT 'UNCONFIRMED'
                               CHECK (current_parcel_state IN (
                                 'UNCONFIRMED', 'IN_CERELO_CUSTODY', 'ORIGIN_HUB_STAGED',
                                 'BATCH_LOCKED', 'CORRIDOR_TRANSIT', 'DESTINATION_HUB_STAGED',
                                 'FINAL_DELIVERY_STAGED', 'HANDED_OVER'
                               )),
  current_custody_type       TEXT NOT NULL DEFAULT 'SENDER'
                               CHECK (current_custody_type IN (
                                 'SENDER', 'PERSONNEL', 'HUB', 'TRANSIT_PARTNER', 'RECEIVER'
                               )),
  current_custody_holder_id  UUID,
  confirmed_at               TIMESTAMPTZ,
  confirmed_by_personnel_id  UUID REFERENCES public.personnel(id),
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- SECTION 6: PAYMENT OBLIGATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.payment_obligations (
  id                        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  shipment_id               UUID NOT NULL REFERENCES public.shipments(id) ON DELETE CASCADE,
  payer_party               TEXT NOT NULL CHECK (payer_party IN ('SENDER', 'RECEIVER')),
  expected_amount           INT NOT NULL CHECK (expected_amount >= 0),
  status                    TEXT NOT NULL DEFAULT 'PENDING'
                              CHECK (status IN ('NOT_REQUIRED', 'PENDING', 'COLLECTED', 'FAILED', 'REFUSED')),
  collected_at              TIMESTAMPTZ,
  collection_method         TEXT CHECK (collection_method IN ('CASH', 'BANK_TRANSFER')),
  collected_by_personnel_id UUID REFERENCES public.personnel(id),
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_shipment_payer UNIQUE(shipment_id, payer_party)
);

-- =============================================================================
-- SECTION 7: OPERATIONAL EVENTS (Immutable Ledger)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.operational_events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  aggregate_type  TEXT NOT NULL CHECK (aggregate_type IN ('SHIPMENT', 'PARCEL', 'BATCH', 'PAYMENT')),
  aggregate_id    UUID NOT NULL,
  event_type      TEXT NOT NULL,
  actor_id        UUID NOT NULL,
  actor_role      TEXT NOT NULL CHECK (actor_role IN ('CUSTOMER', 'PERSONNEL', 'ADMIN', 'SYSTEM')),
  location_hub_id UUID REFERENCES public.operating_hubs(id),
  payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Updated_at triggers
CREATE TRIGGER trg_shipments_updated_at
  BEFORE UPDATE ON public.shipments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_parcels_updated_at
  BEFORE UPDATE ON public.parcels
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_payment_obligations_updated_at
  BEFORE UPDATE ON public.payment_obligations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =============================================================================
-- SECTION 8: INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_shipments_sender ON public.shipments(sender_customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shipments_receiver ON public.shipments(receiver_customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_shipments_status ON public.shipments(current_status);
CREATE INDEX IF NOT EXISTS idx_shipments_receiver_phone ON public.shipments(receiver_phone_snapshot);
CREATE INDEX IF NOT EXISTS idx_parcels_shipment ON public.parcels(shipment_id);
CREATE INDEX IF NOT EXISTS idx_payment_obligations_shipment ON public.payment_obligations(shipment_id);
CREATE INDEX IF NOT EXISTS idx_operational_events_agg ON public.operational_events(aggregate_id, created_at ASC);

-- =============================================================================
-- SECTION 9: INITIAL V1 SEED DATA (Kano ↔ Katsina)
-- =============================================================================

INSERT INTO public.cities (id, name, code, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Kano', 'KAN', TRUE),
  ('00000000-0000-0000-0000-000000000002', 'Katsina', 'KAT', TRUE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.operating_hubs (id, city_id, name, code, address, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'Kano Central Hub (Kwari)', 'KAN-HUB-01', 'Plot 12 Kwari Textile Market, Fagge, Kano', TRUE),
  ('00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000002', 'Katsina Central Hub', 'KAT-HUB-01', 'No. 45 Kofar Kaura Commercial Layout, Katsina', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.corridors (id, origin_city_id, destination_city_id, origin_hub_id, destination_hub_id, code, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000012', 'KAN-KAT', TRUE),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000011', 'KAT-KAN', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.parcel_size_tiers (id, code, name, description, max_weight_kg, display_order, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000201', 'SMALL', 'Small Package', 'Documents, small electronics, or accessories up to 3kg.', 3.0, 1, TRUE),
  ('00000000-0000-0000-0000-000000000202', 'MEDIUM', 'Medium Package', 'Clothing bundles, shoes, or spare parts up to 10kg.', 10.0, 2, TRUE),
  ('00000000-0000-0000-0000-000000000203', 'LARGE', 'Large Package', 'Textile bales, large electronics, or cartons up to 25kg.', 25.0, 3, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Ensure uuid_generate_v4 is VOLATILE
CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
RETURNS UUID AS $$
  SELECT gen_random_uuid();
$$ LANGUAGE sql VOLATILE;

INSERT INTO public.pricing_rules (id, corridor_id, parcel_size_tier_id, base_price_amount, currency, is_active)
VALUES
  -- Kano -> Katsina
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', 200000, 'NGN', TRUE), -- ₦2,000
  ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000202', 350000, 'NGN', TRUE), -- ₦3,500
  ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000203', 600000, 'NGN', TRUE), -- ₦6,000
  -- Katsina -> Kano
  ('00000000-0000-0000-0000-000000000304', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000201', 200000, 'NGN', TRUE), -- ₦2,000
  ('00000000-0000-0000-0000-000000000305', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000202', 350000, 'NGN', TRUE), -- ₦3,500
  ('00000000-0000-0000-0000-000000000306', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000203', 600000, 'NGN', TRUE)  -- ₦6,000
ON CONFLICT (corridor_id, parcel_size_tier_id) DO NOTHING;

-- =============================================================================
-- SECTION 10: RLS POLICIES
-- =============================================================================

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operating_hubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corridors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcel_size_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pricing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operational_events ENABLE ROW LEVEL SECURITY;

-- Public configuration tables: read-only for authenticated and anon users
CREATE POLICY "cities: public read" ON public.cities FOR SELECT USING (true);
CREATE POLICY "operating_hubs: public read" ON public.operating_hubs FOR SELECT USING (true);
CREATE POLICY "corridors: public read" ON public.corridors FOR SELECT USING (true);
CREATE POLICY "parcel_size_tiers: public read" ON public.parcel_size_tiers FOR SELECT USING (true);
CREATE POLICY "pricing_rules: public read" ON public.pricing_rules FOR SELECT USING (true);

-- Shipments: Sender or Receiver or Staff can view
CREATE POLICY "shipments: view own shipments"
  ON public.shipments FOR SELECT
  USING (
    sender_customer_id = auth.uid() OR
    receiver_customer_id = auth.uid() OR
    (auth.jwt()->>'role') IN ('personnel', 'admin')
  );

-- Parcels: Visible if shipment is visible
CREATE POLICY "parcels: view parcel of own shipment"
  ON public.parcels FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = parcels.shipment_id
        AND (s.sender_customer_id = auth.uid() OR s.receiver_customer_id = auth.uid() OR (auth.jwt()->>'role') IN ('personnel', 'admin'))
    )
  );

-- Payment obligations: Visible if shipment is visible
CREATE POLICY "payment_obligations: view obligations of own shipment"
  ON public.payment_obligations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = payment_obligations.shipment_id
        AND (s.sender_customer_id = auth.uid() OR s.receiver_customer_id = auth.uid() OR (auth.jwt()->>'role') IN ('personnel', 'admin'))
    )
  );

-- Operational events: Visible for participants or staff
CREATE POLICY "operational_events: view events of own shipment"
  ON public.operational_events FOR SELECT
  USING (
    actor_id = auth.uid() OR
    (auth.jwt()->>'role') IN ('personnel', 'admin') OR
    EXISTS (
      SELECT 1 FROM public.shipments s
      WHERE s.id = operational_events.aggregate_id
        AND (s.sender_customer_id = auth.uid() OR s.receiver_customer_id = auth.uid())
    )
  );

-- =============================================================================
-- SECTION 11: RPC FUNCTIONS
-- =============================================================================

-- 1. get_delivery_quote
CREATE OR REPLACE FUNCTION public.get_delivery_quote(
  p_origin_city TEXT,
  p_destination_city TEXT,
  p_size_tier_code TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_corridor_id UUID;
  v_tier_id UUID;
  v_price INT;
  v_currency TEXT;
  v_tier_name TEXT;
  v_tier_desc TEXT;
BEGIN
  -- 1. Resolve active corridor
  SELECT c.id INTO v_corridor_id
  FROM public.corridors c
  JOIN public.cities orig ON orig.id = c.origin_city_id
  JOIN public.cities dest ON dest.id = c.destination_city_id
  WHERE orig.name ILIKE p_origin_city
    AND dest.name ILIKE p_destination_city
    AND c.is_active = TRUE;

  IF v_corridor_id IS NULL THEN
    RAISE EXCEPTION 'Unsupported or inactive corridor: % to %', p_origin_city, p_destination_city
      USING ERRCODE = 'P0002';
  END IF;

  -- 2. Resolve active parcel size tier
  SELECT id, name, description INTO v_tier_id, v_tier_name, v_tier_desc
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_size_tier_code))
    AND is_active = TRUE;

  IF v_tier_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or inactive parcel size tier: %', p_size_tier_code
      USING ERRCODE = 'P0002';
  END IF;

  -- 3. Resolve active pricing rule
  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id = v_corridor_id
    AND parcel_size_tier_id = v_tier_id
    AND is_active = TRUE;

  IF v_price IS NULL THEN
    RAISE EXCEPTION 'No active pricing rule for selected corridor and size tier'
      USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'corridor_id', v_corridor_id,
    'size_tier_id', v_tier_id,
    'size_tier_code', UPPER(TRIM(p_size_tier_code)),
    'size_tier_name', v_tier_name,
    'size_tier_description', v_tier_desc,
    'quoted_price_amount', v_price,
    'currency', v_currency
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Helper: generate_delivery_code
CREATE OR REPLACE FUNCTION public.generate_delivery_code()
RETURNS TEXT AS $$
DECLARE
  v_chars TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; -- excludes 0,1,O,I
  v_code TEXT := 'CRL-';
  v_rand INT;
  i INT;
BEGIN
  -- First 4 characters
  FOR i IN 1..4 LOOP
    v_rand := floor(random() * length(v_chars) + 1)::INT;
    v_code := v_code || substr(v_chars, v_rand, 1);
  END LOOP;
  v_code := v_code || '-';
  -- Second 4 characters
  FOR i IN 1..4 LOOP
    v_rand := floor(random() * length(v_chars) + 1)::INT;
    v_code := v_code || substr(v_chars, v_rand, 1);
  END LOOP;
  RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- 3. create_shipment_request (Atomic Transaction)
CREATE OR REPLACE FUNCTION public.create_shipment_request(
  p_origin_city TEXT,
  p_destination_city TEXT,
  p_sender_pickup_address TEXT,
  p_receiver_name TEXT,
  p_receiver_phone TEXT,
  p_receiver_delivery_address TEXT,
  p_parcel_size_code TEXT,
  p_category_description TEXT,
  p_payment_mode TEXT,
  p_sender_payment_amount INT DEFAULT NULL,
  p_delivery_instructions TEXT DEFAULT NULL,
  p_landmark TEXT DEFAULT NULL,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_customer RECORD;
  v_corridor RECORD;
  v_tier RECORD;
  v_price INT;
  v_currency TEXT;
  v_delivery_code TEXT;
  v_shipment_id UUID;
  v_parcel_id UUID;
  v_sender_obligation INT;
  v_receiver_obligation INT;
  v_normalized_receiver_phone TEXT;
  v_existing_shipment RECORD;
BEGIN
  -- 1. Security check: caller must be authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- 2. Verify customer is active and onboarding is complete
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found.' USING ERRCODE = 'P0002';
  END IF;

  IF v_customer.onboarding_completed_at IS NULL THEN
    RAISE EXCEPTION 'Customer onboarding must be completed before requesting shipments.'
      USING ERRCODE = '23514';
  END IF;

  -- 3. Check idempotency: if same key exists for this user, return existing record
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) != '' THEN
    SELECT * INTO v_existing_shipment
    FROM public.shipments
    WHERE idempotency_key = TRIM(p_idempotency_key)
      AND sender_customer_id = v_user_id;

    IF v_existing_shipment IS NOT NULL THEN
      RETURN jsonb_build_object(
        'id', v_existing_shipment.id,
        'delivery_code', v_existing_shipment.delivery_code,
        'current_status', v_existing_shipment.current_status,
        'origin_city', v_existing_shipment.origin_city,
        'destination_city', v_existing_shipment.destination_city,
        'quoted_price_amount', v_existing_shipment.quoted_price_amount,
        'final_price_amount', v_existing_shipment.final_price_amount,
        'payment_mode', v_existing_shipment.payment_mode,
        'created_at', v_existing_shipment.created_at,
        'is_duplicate', true
      );
    END IF;
  END IF;

  -- 4. Validate and resolve Corridor
  SELECT c.*, orig.name AS orig_name, dest.name AS dest_name
  INTO v_corridor
  FROM public.corridors c
  JOIN public.cities orig ON orig.id = c.origin_city_id
  JOIN public.cities dest ON dest.id = c.destination_city_id
  WHERE orig.name ILIKE TRIM(p_origin_city)
    AND dest.name ILIKE TRIM(p_destination_city)
    AND c.is_active = TRUE;

  IF v_corridor IS NULL THEN
    RAISE EXCEPTION 'Unsupported corridor: % to %', p_origin_city, p_destination_city
      USING ERRCODE = 'P0002';
  END IF;

  -- 5. Validate and resolve Parcel Size Tier
  SELECT * INTO v_tier
  FROM public.parcel_size_tiers
  WHERE code = UPPER(TRIM(p_parcel_size_code))
    AND is_active = TRUE;

  IF v_tier IS NULL THEN
    RAISE EXCEPTION 'Invalid parcel size tier: %', p_parcel_size_code
      USING ERRCODE = 'P0002';
  END IF;

  -- 6. Authoritative Pricing calculation (server-derived, cannot be manipulated by client)
  SELECT base_price_amount, currency INTO v_price, v_currency
  FROM public.pricing_rules
  WHERE corridor_id = v_corridor.id
    AND parcel_size_tier_id = v_tier.id
    AND is_active = TRUE;

  IF v_price IS NULL THEN
    RAISE EXCEPTION 'No active pricing rule found for route.' USING ERRCODE = 'P0002';
  END IF;

  -- 7. Validate Receiver details
  IF p_receiver_name IS NULL OR TRIM(p_receiver_name) = '' THEN
    RAISE EXCEPTION 'Receiver name is required.' USING ERRCODE = '23514';
  END IF;

  IF p_receiver_phone IS NULL OR TRIM(p_receiver_phone) = '' THEN
    RAISE EXCEPTION 'Receiver phone number is required.' USING ERRCODE = '23514';
  END IF;

  -- Basic Nigerian phone normalization (+234 format)
  v_normalized_receiver_phone := regexp_replace(p_receiver_phone, '[\s\-\(\)]', '', 'g');
  IF v_normalized_receiver_phone LIKE '0%' AND length(v_normalized_receiver_phone) = 11 THEN
    v_normalized_receiver_phone := '+234' || substr(v_normalized_receiver_phone, 2);
  ELSIF v_normalized_receiver_phone LIKE '234%' AND length(v_normalized_receiver_phone) = 13 THEN
    v_normalized_receiver_phone := '+' || v_normalized_receiver_phone;
  END IF;

  IF p_receiver_delivery_address IS NULL OR TRIM(p_receiver_delivery_address) = '' THEN
    RAISE EXCEPTION 'Receiver delivery address is required.' USING ERRCODE = '23514';
  END IF;

  IF p_sender_pickup_address IS NULL OR TRIM(p_sender_pickup_address) = '' THEN
    RAISE EXCEPTION 'Pickup address is required.' USING ERRCODE = '23514';
  END IF;

  -- 8. Validate Payment Mode & Calculate Obligations
  IF UPPER(TRIM(p_payment_mode)) NOT IN ('SENDER_PAYS', 'RECEIVER_PAYS', 'SPLIT_PAYMENT') THEN
    RAISE EXCEPTION 'Invalid payment mode: %', p_payment_mode USING ERRCODE = '23514';
  END IF;

  IF UPPER(TRIM(p_payment_mode)) = 'SENDER_PAYS' THEN
    v_sender_obligation := v_price;
    v_receiver_obligation := 0;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'RECEIVER_PAYS' THEN
    v_sender_obligation := 0;
    v_receiver_obligation := v_price;
  ELSIF UPPER(TRIM(p_payment_mode)) = 'SPLIT_PAYMENT' THEN
    IF p_sender_payment_amount IS NULL OR p_sender_payment_amount <= 0 OR p_sender_payment_amount >= v_price THEN
      RAISE EXCEPTION 'For Split Payment, sender amount must be strictly between 0 and total price (%)', v_price
        USING ERRCODE = '23514';
    END IF;
    v_sender_obligation := p_sender_payment_amount;
    v_receiver_obligation := v_price - p_sender_payment_amount;
  END IF;

  -- 9. Generate non-sequential Delivery Code
  v_delivery_code := public.generate_delivery_code();

  -- 10. Atomic Insert: shipments
  INSERT INTO public.shipments (
    delivery_code,
    sender_customer_id,
    corridor_id,
    origin_city,
    destination_city,
    origin_hub_id,
    destination_hub_id,
    sender_name_snapshot,
    sender_phone_snapshot,
    sender_pickup_address_snapshot,
    receiver_name_snapshot,
    receiver_phone_snapshot,
    receiver_delivery_address_snapshot,
    delivery_instructions,
    landmark,
    quoted_price_amount,
    final_price_amount,
    currency,
    payment_mode,
    current_status,
    idempotency_key
  )
  VALUES (
    v_delivery_code,
    v_user_id,
    v_corridor.id,
    v_corridor.orig_name,
    v_corridor.dest_name,
    v_corridor.origin_hub_id,
    v_corridor.destination_hub_id,
    v_customer.full_name,
    COALESCE(v_customer.phone_number, ''),
    TRIM(p_sender_pickup_address),
    TRIM(p_receiver_name),
    v_normalized_receiver_phone,
    TRIM(p_receiver_delivery_address),
    NULLIF(TRIM(p_delivery_instructions), ''),
    NULLIF(TRIM(p_landmark), ''),
    v_price,
    v_price,
    v_currency,
    UPPER(TRIM(p_payment_mode)),
    'REQUESTED',
    NULLIF(TRIM(p_idempotency_key), '')
  )
  RETURNING id INTO v_shipment_id;

  -- 11. Atomic Insert: parcels (1-to-1)
  INSERT INTO public.parcels (
    shipment_id,
    sender_declared_size_id,
    category_description,
    current_parcel_state,
    current_custody_type
  )
  VALUES (
    v_shipment_id,
    v_tier.id,
    COALESCE(NULLIF(TRIM(p_category_description), ''), 'General Goods'),
    'UNCONFIRMED',
    'SENDER'
  )
  RETURNING id INTO v_parcel_id;

  -- 12. Atomic Insert: payment_obligations
  IF v_sender_obligation > 0 THEN
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'SENDER', v_sender_obligation, 'PENDING');
  ELSE
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'SENDER', 0, 'NOT_REQUIRED');
  END IF;

  IF v_receiver_obligation > 0 THEN
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'RECEIVER', v_receiver_obligation, 'PENDING');
  ELSE
    INSERT INTO public.payment_obligations (shipment_id, payer_party, expected_amount, status)
    VALUES (v_shipment_id, 'RECEIVER', 0, 'NOT_REQUIRED');
  END IF;

  -- 13. Atomic Insert: operational_events (SHIPMENT_REQUESTED)
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
    v_shipment_id,
    'SHIPMENT_REQUESTED',
    v_user_id,
    'CUSTOMER',
    v_corridor.origin_hub_id,
    jsonb_build_object(
      'delivery_code', v_delivery_code,
      'route', v_corridor.code,
      'payment_mode', UPPER(TRIM(p_payment_mode)),
      'price', v_price
    )
  );

  -- 14. Return sanitized result
  RETURN jsonb_build_object(
    'id', v_shipment_id,
    'delivery_code', v_delivery_code,
    'current_status', 'REQUESTED',
    'origin_city', v_corridor.orig_name,
    'destination_city', v_corridor.dest_name,
    'quoted_price_amount', v_price,
    'final_price_amount', v_price,
    'currency', v_currency,
    'payment_mode', UPPER(TRIM(p_payment_mode)),
    'sender_name_snapshot', v_customer.full_name,
    'receiver_name_snapshot', TRIM(p_receiver_name),
    'created_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_delivery_quote(TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_shipment_request(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT) TO authenticated;
