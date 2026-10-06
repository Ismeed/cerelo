-- =============================================================================
-- Cerelo V1 — Cancellation Constraints Update
-- Version: 20260817000013
-- Description: Expands CHECK constraints on payment_obligations and parcels
--              to permit CANCELLED and CANCELLED_PENDING_RETURN states.
-- =============================================================================

-- 1. Expand payment_obligations status check constraint
ALTER TABLE public.payment_obligations
  DROP CONSTRAINT IF EXISTS payment_obligations_status_check;

ALTER TABLE public.payment_obligations
  ADD CONSTRAINT payment_obligations_status_check
  CHECK (status IN ('NOT_REQUIRED', 'PENDING', 'COLLECTED', 'FAILED', 'REFUSED', 'CANCELLED'));

-- 2. Expand parcels current_parcel_state check constraint
ALTER TABLE public.parcels
  DROP CONSTRAINT IF EXISTS parcels_current_parcel_state_check;

ALTER TABLE public.parcels
  ADD CONSTRAINT parcels_current_parcel_state_check
  CHECK (current_parcel_state IN (
    'UNCONFIRMED', 'IN_CERELO_CUSTODY', 'ORIGIN_HUB_STAGED',
    'BATCH_LOCKED', 'CORRIDOR_TRANSIT', 'DESTINATION_HUB_STAGED',
    'FINAL_DELIVERY_STAGED', 'HANDED_OVER', 'CANCELLED', 'CANCELLED_PENDING_RETURN'
  ));
