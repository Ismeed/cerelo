# CERELO V1 — PRODUCTION RELEASE CHECKLIST

> **Pre-flight readiness checklist for launching Cerelo V1 on the Kano ↔ Katsina corridor.**

---

## 1. PRE-DEPLOYMENT VERIFICATION

- [x] **Repository Cleanliness:** No committed secrets, API keys, or `.env` files.
- [x] **Linter & Static Analysis:** `flutter analyze` clean, TypeScript check clean.
- [x] **Automated Tests:** All core, api, personnel, and admin tests pass.
- [x] **Scope Guardrails:** Zero intracity, smart box, live GPS, customer wallet, or courier marketplace features.

---

## 2. PRODUCTION DATABASE & CONFIGURATION

- [x] **PostgreSQL Migrations (1 to 10):**
  1. `20260817000001_initial_schema.sql`
  2. `20260817000002_customer_auth_domain.sql`
  3. `20260817000003_shipment_request_domain.sql`
  4. `20260817000004_delivery_code_and_sharing.sql`
  5. `20260817000005_personnel_and_pickup_domain.sql`
  6. `20260817000006_parcel_qr_and_hub_processing.sql`
  7. `20260817000007_batch_and_middle_mile_domain.sql`
  8. `20260817000008_destination_and_final_mile_domain.sql`
  9. `20260817000009_admin_and_operations_control_domain.sql`
  10. `20260817000010_notifications_and_reliability.sql`
- [x] **Row Level Security:** Enabled and verified on all 14 tables.
- [x] **Baseline Corridors:** `KAN-KAT` (Kano $\rightarrow$ Katsina) and `KAT-KAN` (Katsina $\rightarrow$ Kano) configured as active.
- [x] **Parcel Size Tiers:** Small (₦2,000), Medium (₦3,500), Large (₦6,000) base rules configured.

---

## 3. CLIENT APPLICATIONS READY

- [x] **Customer Mobile App (`apps/customer_app`):**
  - Authentication (Google / Email OTP)
  - Send Package wizard (Kano $\leftrightarrow$ Katsina only)
  - Delivery Code display & secure link sharing
  - Milestone timeline (`Requested` $\rightarrow$ `Delivered`)
  - Secondary receiver receipt confirmation
- [x] **Personnel Field App (`apps/personnel_app`):**
  - Pickup queue & receiver verification call
  - Size correction & physical cash recording
  - High-contrast printable PDF parcel/batch labels
  - Draft batching & manifest confirmation
  - Atomic middle-mile onboarding
  - Destination reconciliation & discrepancy logging
  - Final-mile doorstep delivery & mandatory Sender completion call SOP
- [x] **Admin Operations Web (`apps/admin_web`):**
  - Live operations overview dashboard & corridor metrics
  - Shipment search & audited receiver corrections
  - Personnel access & suspension management
  - Incident resolution with mandatory notes
  - Directional corridor toggles & base pricing editor
  - Immutable audit logs

---

## 4. SIGN-OFF DECISION

> **Cerelo V1 is certified READY FOR CONTROLLED KANO ↔ KATSINA PILOT LAUNCH.**
