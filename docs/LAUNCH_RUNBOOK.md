# CERELO V1 — Production Launch & Operations Runbook

> **Status**: AUTHORITATIVE LAUNCH & DISASTER RECOVERY RUNBOOK  
> **Environment**: Production (`cerelo-production` / `mgffdifedhquwiirkhyy` in `eu-west-1`)  
> **Corridor**: Kano ↔ Katsina Only  
> **Last Updated**: 2026-08-22  

---

## 1. Pre-Launch Verification Checklist

Before accepting live commercial shipments:
- [x] Official domain `https://cerelonet.com` active with valid TLS certificate.
- [x] Apex and `www` permanent 308 redirects verified.
- [x] Production database verified on 19/19 forward migrations.
- [x] Email OTP and Google OAuth verified on production Auth endpoints.
- [x] Resend custom SMTP (`auth@cerelonet.com`), DKIM, and DMARC active.
- [x] Public tracking RPC (`get_public_shipment_tracking`) audited for zero-PII emission.
- [x] Row Level Security (RLS) active and enforced across all tables.
- [ ] Commercial pricing approved by management and activated (`is_approved_for_production = TRUE`).
- [ ] Customer Flutter App build packaged with `.dart_define.production.json`.
- [ ] Personnel Flutter App build packaged with `.dart_define.production.json`.
- [ ] Operations Admin console deployed to `admin.cerelonet.com`.

---

## 2. Production Database Backup & Recovery Procedure

### A. Recovery Time & Point Objectives
- **RTO (Recovery Time Objective)**: < 2 Hours for complete database restoration.
- **RPO (Recovery Point Objective)**: < 24 Hours for full backup snapshot; immediate recovery for transactional outbox logs.

### B. Manual Daily Schema & Data Backup Procedure
Run daily via authenticated Management API or CLI:
```bash
# 1. Export schema snapshot
supabase db dump --project-ref mgffdifedhquwiirkhyy --schema public > backups/cerelo_prod_schema_$(date +%Y%m%d).sql

# 2. Export roles and permissions
supabase db dump --project-ref mgffdifedhquwiirkhyy --schema auth > backups/cerelo_prod_auth_$(date +%Y%m%d).sql
```

### C. Disaster Recovery Plan
1. In the event of primary database corruption or region failure:
   - Provision a fresh Supabase project in `eu-west-1`.
   - Apply sequential migrations `20260817000001` through `19`.
   - Restore customer and shipment data from the latest verified SQL snapshot.
   - Update Vercel and Flutter production `.dart_define.production.json` endpoint URLs.
   - Execute regression tests before re-opening shipment booking.

---

## 3. First Admin Account Bootstrap Procedure

Creating an authorized Operations Admin is a privileged action:
1. Admin user signs up via Email OTP in the Admin console.
2. Super-admin executes the SQL role elevation inside an authenticated transaction:
```sql
-- Privileged bootstrap: elevate user to admin
UPDATE auth.users 
SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb 
WHERE email = 'operations-lead@cerelonet.com';

INSERT INTO public.admin_users (id, full_name, role, is_active)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'operations-lead@cerelonet.com'),
  'Operations Lead',
  'super_admin',
  true
)
ON CONFLICT (id) DO UPDATE SET is_active = true;
```
3. Elevation event is recorded in the immutable administrative audit log.
