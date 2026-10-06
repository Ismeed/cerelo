-- =============================================================================
-- Cerelo V1 — Customer Authentication & Onboarding Migration
-- Version: 20260817000002
-- Description: Customer profile schema enhancements for Google & Email onboarding,
--              onboarding completion RPC, current-customer resolution query, and profile update RPC.
-- =============================================================================

-- 1. Modify phone_number constraint on customers table
-- Phone number is optional during customer onboarding (receiver phone belongs to shipment creation)
ALTER TABLE public.customers ALTER COLUMN phone_number DROP NOT NULL;

-- 2. Add onboarding_completed_at to track onboarding state authoritatively
ALTER TABLE public.customers 
  ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ DEFAULT NULL;

-- 3. Enforce Business Account consistency:
-- Once onboarding is complete, a Business account MUST have a non-empty business_name
ALTER TABLE public.customers
  DROP CONSTRAINT IF EXISTS check_customer_business_name,
  ADD CONSTRAINT check_customer_business_name 
    CHECK (
      onboarding_completed_at IS NULL 
      OR account_type != 'BUSINESS' 
      OR (business_name IS NOT NULL AND char_length(trim(business_name)) > 0)
    );

-- 4. Update the customer auto-creation trigger on auth.users signup
CREATE OR REPLACE FUNCTION public.handle_new_customer_signup()
RETURNS TRIGGER AS $$
DECLARE
  v_extracted_name TEXT;
  v_extracted_phone TEXT;
BEGIN
  -- Only handle customer role (or when role is unset in metadata)
  IF (NEW.raw_app_meta_data->>'role' IS NULL OR NEW.raw_app_meta_data->>'role' = 'customer') THEN
    v_extracted_name := COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      NEW.raw_user_meta_data->>'user_name',
      ''
    );
    
    v_extracted_phone := NULLIF(TRIM(COALESCE(NEW.phone, '')), '');

    INSERT INTO public.customers (
      id,
      full_name,
      phone_number,
      account_type,
      business_name,
      onboarding_completed_at
    )
    VALUES (
      NEW.id,
      CASE WHEN char_length(trim(v_extracted_name)) >= 2 THEN trim(v_extracted_name) ELSE 'Customer' END,
      v_extracted_phone,
      'INDIVIDUAL',
      NULL,
      NULL -- Onboarding is NOT complete upon raw auth signup
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: Get current customer profile (idempotent profile resolution)
CREATE OR REPLACE FUNCTION public.get_current_customer()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_customer RECORD;
  v_auth_user RECORD;
  v_email TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  -- Lookup customer profile
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id;

  -- If customer record does not exist (e.g. trigger race/edge case), resolve idempotently
  IF NOT FOUND THEN
    SELECT * INTO v_auth_user FROM auth.users WHERE id = v_user_id;
    
    INSERT INTO public.customers (
      id,
      full_name,
      phone_number,
      account_type,
      business_name,
      onboarding_completed_at
    )
    VALUES (
      v_user_id,
      COALESCE(
        NULLIF(TRIM(v_auth_user.raw_user_meta_data->>'full_name'), ''),
        NULLIF(TRIM(v_auth_user.raw_user_meta_data->>'name'), ''),
        'Customer'
      ),
      NULLIF(TRIM(COALESCE(v_auth_user.phone, '')), ''),
      'INDIVIDUAL',
      NULL,
      NULL
    )
    ON CONFLICT (id) DO UPDATE SET updated_at = NOW()
    RETURNING * INTO v_customer;
  END IF;

  -- Get authenticated email from auth.users
  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_customer.id,
    'email', v_email,
    'full_name', v_customer.full_name,
    'phone_number', v_customer.phone_number,
    'account_type', v_customer.account_type,
    'business_name', v_customer.business_name,
    'is_active', v_customer.is_active,
    'onboarding_completed_at', v_customer.onboarding_completed_at,
    'created_at', v_customer.created_at,
    'updated_at', v_customer.updated_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 6. RPC: Complete Customer Onboarding (Atomic Transaction)
CREATE OR REPLACE FUNCTION public.complete_customer_onboarding(
  p_account_type TEXT,
  p_business_name TEXT DEFAULT NULL,
  p_full_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_clean_account_type TEXT;
  v_clean_business_name TEXT;
  v_clean_full_name TEXT;
  v_customer RECORD;
  v_email TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  v_clean_account_type := UPPER(TRIM(p_account_type));
  IF v_clean_account_type NOT IN ('INDIVIDUAL', 'BUSINESS') THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Account type must be INDIVIDUAL or BUSINESS.'
      USING ERRCODE = 'P0002';
  END IF;

  v_clean_business_name := NULLIF(TRIM(p_business_name), '');
  IF v_clean_account_type = 'BUSINESS' AND v_clean_business_name IS NULL THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Business / Shop Name is required for Business accounts.'
      USING ERRCODE = 'P0002';
  END IF;

  -- Ensure profile exists
  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.customers (id, full_name, account_type)
    VALUES (v_user_id, 'Customer', 'INDIVIDUAL')
    RETURNING * INTO v_customer;
  END IF;

  v_clean_full_name := NULLIF(TRIM(p_full_name), '');
  IF v_clean_full_name IS NOT NULL THEN
    IF char_length(v_clean_full_name) < 2 OR char_length(v_clean_full_name) > 100 THEN
      RAISE EXCEPTION 'VALIDATION_ERROR: Full Name must be between 2 and 100 characters.'
        USING ERRCODE = 'P0002';
    END IF;
  ELSE
    v_clean_full_name := v_customer.full_name;
  END IF;

  -- Atomically update customer record to completed state
  UPDATE public.customers
  SET
    account_type = v_clean_account_type,
    business_name = CASE WHEN v_clean_account_type = 'BUSINESS' THEN v_clean_business_name ELSE NULL END,
    full_name = v_clean_full_name,
    onboarding_completed_at = COALESCE(onboarding_completed_at, NOW()),
    updated_at = NOW()
  WHERE id = v_user_id
  RETURNING * INTO v_customer;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_customer.id,
    'email', v_email,
    'full_name', v_customer.full_name,
    'phone_number', v_customer.phone_number,
    'account_type', v_customer.account_type,
    'business_name', v_customer.business_name,
    'is_active', v_customer.is_active,
    'onboarding_completed_at', v_customer.onboarding_completed_at,
    'created_at', v_customer.created_at,
    'updated_at', v_customer.updated_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 7. RPC: Update Customer Profile (Post-onboarding safe profile updates)
CREATE OR REPLACE FUNCTION public.update_customer_profile(
  p_full_name TEXT DEFAULT NULL,
  p_business_name TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_clean_full_name TEXT;
  v_clean_business_name TEXT;
  v_customer RECORD;
  v_email TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Authentication required.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_customer FROM public.customers WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: Customer profile not found.'
      USING ERRCODE = 'P0002';
  END IF;

  IF p_full_name IS NOT NULL THEN
    v_clean_full_name := TRIM(p_full_name);
    IF char_length(v_clean_full_name) < 2 OR char_length(v_clean_full_name) > 100 THEN
      RAISE EXCEPTION 'VALIDATION_ERROR: Full Name must be between 2 and 100 characters.'
        USING ERRCODE = 'P0002';
    END IF;
  ELSE
    v_clean_full_name := v_customer.full_name;
  END IF;

  IF v_customer.account_type = 'BUSINESS' AND p_business_name IS NOT NULL THEN
    v_clean_business_name := TRIM(p_business_name);
    IF char_length(v_clean_business_name) < 2 OR char_length(v_clean_business_name) > 100 THEN
      RAISE EXCEPTION 'VALIDATION_ERROR: Business Name must be between 2 and 100 characters.'
        USING ERRCODE = 'P0002';
    END IF;
  ELSE
    v_clean_business_name := v_customer.business_name;
  END IF;

  UPDATE public.customers
  SET
    full_name = v_clean_full_name,
    business_name = CASE WHEN account_type = 'BUSINESS' THEN v_clean_business_name ELSE NULL END,
    updated_at = NOW()
  WHERE id = v_user_id
  RETURNING * INTO v_customer;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_customer.id,
    'email', v_email,
    'full_name', v_customer.full_name,
    'phone_number', v_customer.phone_number,
    'account_type', v_customer.account_type,
    'business_name', v_customer.business_name,
    'is_active', v_customer.is_active,
    'onboarding_completed_at', v_customer.onboarding_completed_at,
    'created_at', v_customer.created_at,
    'updated_at', v_customer.updated_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- 8. Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_current_customer TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_customer_onboarding TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_customer_profile TO authenticated;
