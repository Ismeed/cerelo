-- =============================================================================
-- Cerelo V1 — Development Seed Data
-- WARNING: DEVELOPMENT ONLY. Never run against staging or production.
-- =============================================================================
-- This file seeds synthetic test configuration data for local development.
-- DO NOT include real customer names, phones, or addresses.
-- All test data uses clearly synthetic values (e.g., "Test Customer 01").
-- =============================================================================

-- Placeholder: geographic and pricing configuration tables will be seeded
-- in the migration that defines those entities.
--
-- Intended seed structure (uncomment once tables exist):
--
-- INSERT INTO public.cities (id, name, slug, is_active) VALUES
--   (uuid_generate_v4(), 'Kano',    'kano',    TRUE),
--   (uuid_generate_v4(), 'Katsina', 'katsina', TRUE);
--
-- INSERT INTO public.corridors (id, origin_city_id, destination_city_id, is_active) VALUES ...
--
-- INSERT INTO public.parcel_size_tiers (id, size, display_label, base_price_kobo) VALUES
--   (uuid_generate_v4(), 'SMALL',  'Small',  150000),   -- ₦1,500
--   (uuid_generate_v4(), 'MEDIUM', 'Medium', 300000),   -- ₦3,000
--   (uuid_generate_v4(), 'LARGE',  'Large',  600000);   -- ₦6,000

SELECT 'Cerelo V1 development seed loaded (placeholder).' AS status;
