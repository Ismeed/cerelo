-- =============================================================================
-- Cerelo V1 — Fix: onboard_batch regression introduced in migration 30
-- Version: 20260910000031
-- Description:
--   Migration 20260910000030 (outbound batch hub-scope fix) mistakenly
--   simplified onboard_batch's per-parcel transition to
--   current_parcel_state = 'IN_TRANSIT', which is not a valid value for
--   parcels.current_parcel_state and was rejected by the table's CHECK
--   constraint (caught immediately by Phase 3 retest on staging — the
--   original migration 20260817000007 value is 'CORRIDOR_TRANSIT' with
--   current_custody_type = 'TRANSIT_PARTNER').
--
--   This migration restores the exact original per-parcel state/custody
--   transition and event set from migration 20260817000007, while keeping
--   the operating-hub authorization check added in migration
--   20260910000030. No other behavior changes. Forward-only migration;
--   migrations 01-30 are not edited.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.onboard_batch(p_batch_id UUID)
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

  IF v_personnel.operating_hub_id IS DISTINCT FROM v_batch.origin_hub_id THEN
    RAISE EXCEPTION 'Forbidden: This batch does not belong to your operating hub.' USING ERRCODE = '42501';
  END IF;

  IF v_batch.current_batch_state = 'ONBOARDED' THEN
    RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'status', 'ONBOARDED', 'already_onboarded', true);
  END IF;

  IF v_batch.current_batch_state != 'CONFIRMED' THEN
    RAISE EXCEPTION 'Batch must be CONFIRMED before it can be onboarded (current state: %)', v_batch.current_batch_state
      USING ERRCODE = '23514';
  END IF;

  UPDATE public.batches
  SET current_batch_state = 'ONBOARDED', onboarded_by_personnel_id = v_personnel.id, onboarded_at = NOW()
  WHERE id = p_batch_id;

  IF v_batch.transit_run_id IS NOT NULL THEN
    UPDATE public.transit_runs SET status = 'DEPARTED', actual_departure_at = NOW() WHERE id = v_batch.transit_run_id;
  END IF;

  FOR v_parcel IN
    SELECT p.* FROM public.parcels p
    JOIN public.batch_memberships bm ON bm.parcel_id = p.id
    WHERE bm.batch_id = p_batch_id AND bm.is_active = TRUE
  LOOP
    UPDATE public.parcels
    SET current_parcel_state = 'CORRIDOR_TRANSIT',
        current_custody_type = 'TRANSIT_PARTNER'
    WHERE id = v_parcel.id;

    UPDATE public.shipments SET current_status = 'IN_TRANSIT' WHERE id = v_parcel.shipment_id;

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'PARCEL', v_parcel.id, 'CORRIDOR_TRANSIT_STARTED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
      jsonb_build_object('batch_id', p_batch_id, 'batch_reference', v_batch.batch_reference)
    );

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'PARCEL', v_parcel.id, 'CUSTODY_TRANSFERRED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
      jsonb_build_object('from_custody', 'HUB', 'to_custody', 'TRANSIT_PARTNER', 'batch_id', p_batch_id)
    );

    INSERT INTO public.operational_events (
      aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
    ) VALUES (
      'SHIPMENT', v_parcel.shipment_id, 'SHIPMENT_IN_TRANSIT', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
      jsonb_build_object('status', 'IN_TRANSIT')
    );
  END LOOP;

  INSERT INTO public.operational_events (
    aggregate_type, aggregate_id, event_type, actor_id, actor_role, location_hub_id, payload
  ) VALUES (
    'BATCH', p_batch_id, 'BATCH_ONBOARDED', v_personnel.id, 'PERSONNEL', v_batch.origin_hub_id,
    jsonb_build_object('batch_reference', v_batch.batch_reference, 'transit_run_id', v_batch.transit_run_id, 'parcel_count', v_batch.manifest_parcel_count)
  );

  RETURN jsonb_build_object('success', true, 'batch_id', p_batch_id, 'status', 'ONBOARDED', 'already_onboarded', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.onboard_batch(UUID) TO authenticated;
