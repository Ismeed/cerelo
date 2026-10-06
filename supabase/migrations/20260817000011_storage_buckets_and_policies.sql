-- =============================================================================
-- Cerelo V1 — Storage Buckets & Access Policies Migration
-- Version: 20260817000011
-- Description: Creates private storage buckets for printable parcel labels and
--              batch container manifests with strict Row Level Security policies.
-- =============================================================================

-- 1. Create private storage buckets if they do not exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('parcel-labels', 'parcel-labels', FALSE, 5242880, ARRAY['application/pdf', 'image/png']),
  ('batch-manifests', 'batch-manifests', FALSE, 10485760, ARRAY['application/pdf', 'image/png'])
ON CONFLICT (id) DO NOTHING;

-- 2. Enable Storage RLS Policies for parcel-labels bucket
CREATE POLICY "Personnel can upload parcel labels"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'parcel-labels' AND
    EXISTS (SELECT 1 FROM public.personnel WHERE id = auth.uid() AND is_active = TRUE)
  );

CREATE POLICY "Personnel and Admins can view parcel labels"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'parcel-labels' AND (
      EXISTS (SELECT 1 FROM public.personnel WHERE id = auth.uid() AND is_active = TRUE) OR
      EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND is_active = TRUE) OR
      EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
    )
  );

-- 3. Enable Storage RLS Policies for batch-manifests bucket
CREATE POLICY "Personnel can upload batch manifests"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'batch-manifests' AND
    EXISTS (SELECT 1 FROM public.personnel WHERE id = auth.uid() AND is_active = TRUE)
  );

CREATE POLICY "Personnel and Admins can view batch manifests"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'batch-manifests' AND (
      EXISTS (SELECT 1 FROM public.personnel WHERE id = auth.uid() AND is_active = TRUE) OR
      EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND is_active = TRUE) OR
      EXISTS (SELECT 1 FROM public.admins WHERE user_id = auth.uid())
    )
  );
