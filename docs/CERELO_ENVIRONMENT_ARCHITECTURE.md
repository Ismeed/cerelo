# CERELO — Backend Environment Architecture & Separation

> **Status**: ACTIVE & LOCKED  
> **Last Updated**: 2026-08-22  
> **Classification**: Platform Operations & Data Governance  

---

## 1. Executive Summary

CERELO V1 strictly enforces complete physical and logical isolation between development, staging, and production backend environments. Staging and Production operate on independent, dedicated Supabase Cloud projects located in `eu-west-1` (Ireland) with zero shared state, zero shared credentials, and zero cross-environment database links.

```
┌────────────────────────────────────────┐       ┌────────────────────────────────────────┐
│             CERELO STAGING             │       │           CERELO PRODUCTION            │
│  Project Ref: plsoyomwoqysharmuddl     │       │  Project Ref: mgffdifedhquwiirkhyy     │
│  Region: eu-west-1 (Ireland)           │       │  Region: eu-west-1 (Ireland)           │
│  Target: Preview / Staging Deployments │       │  Target: Official Production Domain    │
│  State: Active Synthetic Test Data     │       │  State: Clean (0 Test Rows / 0 Test PII)│
└────────────────────────────────────────┘       └────────────────────────────────────────┘
```

---

## 2. Environment Inventory & Matrix

| Attribute | Staging Environment | Production Environment | Isolation Rule |
| :--- | :--- | :--- | :--- |
| **Project Name** | `cerelo-staging` | `cerelo-production` | Dedicated project |
| **Project Ref** | `plsoyomwoqysharmuddl` | `mgffdifedhquwiirkhyy` | Separate project IDs |
| **Cloud Region** | `eu-west-1` (Ireland) | `eu-west-1` (Ireland) | Parity region |
| **Base URL** | `https://plsoyomwoqysharmuddl.supabase.co` | `https://mgffdifedhquwiirkhyy.supabase.co` | Dedicated endpoints |
| **Vercel Scope** | Preview & Development | Production (`cerelonet.com`, `www`) | Strict environment scoping |
| **Auth Site URL** | `com.cerelo.customer://login-callback/` | `com.cerelo.customer://login-callback/` | App scheme callback |
| **Google OAuth Callback** | `https://plsoyomwoqysharmuddl.supabase.co/auth/v1/callback` | `https://mgffdifedhquwiirkhyy.supabase.co/auth/v1/callback` | Dedicated callback URIs |
| **Migrations** | 19 Migrations (`20260817000001`–`19`) | 19 Migrations (`20260817000001`–`19`) | Forward-only 100% parity |
| **Vault Worker Secret** | Dedicated Staging Secret | Dedicated Production Secret | Independent 256-bit entropy |
| **pg_cron Target** | Staging Edge Function | Production Edge Function | Isolated function dispatch |

---

## 3. Migration Discipline & Parity

All database schema, RLS policies, custom types, and security definer functions are managed exclusively through repository migrations located in `supabase/migrations/`:

```
20260817000001_bootstrap.sql
20260817000002_customer_onboarding.sql
20260817000003_shipment_request_domain.sql
20260817000004_share_tokens_and_delivery_code.sql
20260817000005_personnel_pickup_domain.sql
20260817000006_parcel_qr_and_hub_processing.sql
20260817000007_batch_and_middle_mile_domain.sql
20260817000008_destination_and_final_mile_domain.sql
20260817000009_admin_and_operations_control_domain.sql
20260817000010_notifications_and_reliability.sql
20260817000011_storage_buckets_and_policies.sql
20260817000012_customer_shipment_cancellation.sql
20260817000013_cancellation_constraint_fixes.sql
20260817000014_public_tracking_rpc.sql
20260817000015_harden_public_tracking_rpc.sql
20260817000016_fix_search_path.sql
20260817000017_align_delivery_and_payment_semantics.sql
20260817000018_enforce_physical_cash_collection.sql
20260817000019_fix_mark_delivered_obligation_block.sql
```

### Invariants:
1. **No Manual Remote Schema Edits**: All changes must exist as versioned `.sql` files applied sequentially.
2. **Deterministic Forward Application**: New migrations are tested on local CLI first, applied to Staging, verified, and only then pushed to Production via `supabase db push --project-ref mgffdifedhquwiirkhyy`.
3. **Zero Test Fixtures in Production**: Production migrations contain zero synthetic seed rows. Seed data is strictly restricted to foundation reference tables (`cities`, `operating_hubs`, `corridors`, `parcel_size_tiers`, `pricing_rules`).

---

## 4. Security & Secret Isolation

1. **Service Role Key**:
   - The Service Role Key grants unrestricted database bypass.
   - It is **NEVER** embedded in client-side code, web browsers, or mobile apps.
   - It is restricted to server-side Node.js admin operations and isolated CI runners.

2. **Anon Key & Publishable Key**:
   - Client applications (Mobile App, Public Tracking Web Page) interact solely through the `anon` key.
   - Every table is protected by PostgreSQL Row Level Security (RLS).
   - Anonymous callers cannot read any customer, shipment, personnel, or payment records.
   - Public tracking operates exclusively through the hardened security definer RPC `get_public_shipment_tracking(p_tracking_query TEXT)`.

3. **Notification Worker & Vault Secrets**:
   - Asynchronous push notifications utilize a transactional PostgreSQL outbox (`notification_outbox`).
   - The outbox processor Edge Function (`process-notification-outbox`) requires authentication via `WORKER_SECRET_KEY`.
   - The secret is stored inside `vault.secrets` on each Supabase project.
   - `pg_cron` invokes `public.trigger_notification_outbox_worker()`, which extracts the secret dynamically from `vault.decrypted_secrets` and dispatches via `pg_net`.
   - Production and Staging use completely separate, cryptographically random 256-bit secrets.

---

## 5. Storage Buckets

Both environments maintain the following private storage buckets:
- `parcel-labels`: Private storage (`public: false`) for parcel label PDFs/PNGs. Accessible only by authenticated Personnel and Admins.
- `batch-manifests`: Private storage (`public: false`) for sealed batch manifest PDFs. Accessible only by authenticated Personnel and Admins.

---

## 6. Official Production Domain Architecture (Prompt 9B2 Completed)

The official domain cutover is live:
- **Canonical Apex Domain**: `https://cerelonet.com`
- **Subdomain Redirect**: `https://www.cerelonet.com` (Permanent 308 redirect to apex)
- **Vercel Project**: `cerelo-website` (`prj_oDOGwu5Ud6uMpOKTAb5QA8i3uPxB`)
- **DNS Provider**: Namecheap Advanced DNS (Apex A record: `216.198.79.1`, www CNAME: `75c42407850c19c0.vercel-dns-017.com.`)
- **Email Infrastructure**: Resend DKIM (`resend._domainkey`), DMARC (`_dmarc`), and Custom SMTP (`smtp.resend.com:465`) fully preserved and verified.
- **Production Supabase Site URL**: `https://cerelonet.com`
- **Indexing Status**: `noindex, nofollow` (Pre-launch release status maintained until Prompt 10).

### Vercel Environment Variable Separation Matrix:

| Variable | Preview / Development | Production (`cerelonet.com`) |
| :--- | :--- | :--- |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://plsoyomwoqysharmuddl.supabase.co` | `https://mgffdifedhquwiirkhyy.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Staging Anon Key | Production Anon Key |
| `NEXT_PUBLIC_RELEASE_STAGE` | `prelaunch` | `prelaunch` *(noindex active)* |
| `NEXT_PUBLIC_ENV` | `development` / `staging` | `production` |

---

*Authored for CERELO V1 Architecture & Engineering Operations*
