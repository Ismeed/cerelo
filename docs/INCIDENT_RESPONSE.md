# CERELO V1 — Production Incident Response Runbook

> **Status**: OPERATIONAL INCIDENT MANAGEMENT & ESCALATION PROTOCOL  
> **Classification**: Internal Operations & Security Governance  
> **Last Updated**: 2026-08-22  

---

## 1. Incident Classification & Severity Levels

| Severity | Definition | Target Response | Responsible Role |
|:---|:---|:---:|:---:|
| **SEV-1 (Critical)** | Complete service outage (Database down, Website unreachable, Auth failing for all users, or Security breach) | **Immediate (< 15 mins)** | Technical Lead & Operations Director |
| **SEV-2 (High)** | Core functional degradation (Email OTP delivery delay, Public tracking RPC error, Batch processing blocked) | **< 1 Hour** | Backend Engineer & Hub Supervisor |
| **SEV-3 (Medium)** | Isolated physical anomaly (Single lost parcel report, physical cash discrepancy, receiver dispute) | **< 4 Hours** | Hub Operations Supervisor |
| **SEV-4 (Low)** | Minor UI bug, non-blocking copy issue, or general support inquiry | **< 24 Hours** | Support Team |

---

## 2. Specific Incident Protocols

### Incident 1: Supabase Database Outage (SEV-1)
- **Symptoms**: Customer app shows network error; public tracking fails with HTTP 500/503.
- **Action**:
  1. Verify Supabase Platform Status (`status.supabase.com`).
  2. If platform incident: Enable temporary maintenance notice in apps.
  3. Physical operations protocol: Ground Personnel switches to manual paper custody manifests at hubs; parcel scanning resumed immediately upon database restoration.

### Incident 2: Email OTP Delivery Failure (SEV-2)
- **Symptoms**: Senders report not receiving 6-digit OTP code.
- **Action**:
  1. Inspect Resend Dashboard (`resend.com/emails`) for delivery status, bounces, or reputation issues.
  2. Verify DNS SPF and DKIM records using `cloudflare-dns.com` API.
  3. Direct senders to use Google OAuth federated login as an active alternative.

### Incident 3: Lost or Damaged Parcel in Transit (SEV-3)
- **Symptoms**: Destination hub reconciliation identifies missing parcel during batch unpacking.
- **Action**:
  1. Supervisor immediately flags parcel as `RECONCILIATION_EXCEPTION` in the system.
  2. Contact Middle-Mile Transport driver and Origin Hub supervisor to verify loading manifest.
  3. If untraceable within 24 hours: Escalate to Operations Lead, contact Sender directly, and initiate commercial claims resolution under `docs/OPERATIONS_POLICY.md`.

### Incident 4: Compromised Personnel or Admin Account (SEV-1)
- **Symptoms**: Unauthorized status transitions or suspicious logins reported.
- **Action**:
  1. Deactivate account immediately via Admin Console or direct SQL:
     ```sql
     UPDATE public.personnel SET is_active = false WHERE id = '<USER_UUID>';
     UPDATE public.admin_users SET is_active = false WHERE id = '<USER_UUID>';
     ```
  2. Revoke active auth sessions via Supabase Management API.
  3. Audit `public.operational_events` to identify and rectify any unauthorized state mutations.

### Incident 5: Physical Cash Collection Discrepancy (SEV-3)
- **Symptoms**: Personnel cash settlement at hub end-of-shift does not balance with `public.payment_collections` sum.
- **Action**:
  1. Reconcile collected amounts against shipment obligations in the Admin Console.
  2. Cross-check sender/receiver receipts and phone logs before releasing Personnel shift settlement.
