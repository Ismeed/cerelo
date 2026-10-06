# CERELO V1 SECURITY, RBAC & DATA ACCESS ARCHITECTURE

> **Document Status:** Authoritative Security Contract & Authorization Specification for Cerelo V1  
> **Pre-requisite References:** `CERELO_PRODUCT_CONTEXT.md`, `CERELO_V1_REQUIREMENTS_FREEZE.md`, `CERELO_USER_JOURNEYS_AND_STATE_MACHINE.md`, `CERELO_TECHNICAL_ARCHITECTURE.md`, and `CERELO_DATABASE_AND_BACKEND_DOMAIN_ARCHITECTURE.md`  
> **Target Security Environment:** Zero-Trust Client Architecture + Server-Authoritative Database/RPC Guard  

---

## A. Executive Security Model

Cerelo V1 implements a **Zero-Trust Client Security Model** where client applications (Customer Mobile App, Personnel Mobile App, Admin Web Panel) are treated as untrusted presentation interfaces.

### Core Security Evaluation Model
Every access request and operational mutation is evaluated on the server using a 6-part context tuple:

```
[Identity] + [Role/Permissions] + [Resource Ownership] + [Operational Scope] + [Resource State] + [Command]
```

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              CERELO V1 ZERO-TRUST ACCESS PIPELINE                      │
├───────────────────────┬─────────────────────────────────┬──────────────────────────────┤
│ 1. Identity & Role    │ 2. Relationship & Scope         │ 3. State & Execution         │
├───────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ • Authenticated JWT   │ • Ownership (Sender/Receiver)   │ • State Machine Precondition │
│ • App Metadata Role   │ • Hub / City Assignment Scope   │ • Atomic Transaction RPC     │
│   (Customer/Personnel/│ • Scoped Shared Access Token    │ • Append-only Audit Log      │
│    Admin)             │ • PII Masking / Data Projection │ • Outbox Notification Event  │
└───────────────────────┴─────────────────────────────────┴──────────────────────────────┘
```

---

## B. Trust Boundaries

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                CERELO V1 TRUST BOUNDARIES                              │
├───────────────────────┬─────────────────────────────────┬──────────────────────────────┤
│ Domain Zone           │ Components                      │ Trust Level & Controls       │
├───────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Untrusted Client Zone │ Mobile Apps, Admin Browsers,    │ UNTRUSTED. Client state and  │
│                       │ QR Codes, Shared Links          │ logic cannot enforce security│
├───────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Server Gateway Zone   │ Supabase Auth, Deno Edge        │ HIGH TRUST. Validates JWT,   │
│                       │ Functions, API Proxy            │ rate limits, checks roles    │
├───────────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Core Data Zone        │ PostgreSQL 15+, PL/pgSQL RPCs,  │ MAXIMUM TRUST. Enforces RLS, │
│                       │ Row Level Security (RLS)        │ ACID constraints, audit logs │
└───────────────────────┴─────────────────────────────────┴──────────────────────────────┘
```

1. **Client Untrusted Boundary:** Clients cannot alter lifecycle statuses directly via raw database `UPDATE` queries. All mutations must pass through server-side RPC functions.
2. **Identifier Non-Privilege Boundary:** Knowing a Delivery Code, Parcel QR, or Batch QR grants NO inherent operational authority. Identifiers only resolve resources; access control is determined by the actor's server-authenticated context.
3. **Data Exposure Boundary:** Public tracking views expose sanitized milestone timelines only, masking private Customer PII (phone numbers, full addresses).

---

## C. Identity Model

### 1. Identity Mapping
* **Auth Identity (`auth.users`):** Authenticated user record created by Supabase Auth (Google OAuth or Email).
* **Customer Profile (`customers`):** Application identity for end customers (`account_type`: `INDIVIDUAL` or `BUSINESS`).
* **Personnel Profile (`personnel`):** Application identity for operational field staff (`assigned_hub_id`, `is_active`).
* **Admin Profile (`admin_users`):** Application identity for administrative staff (`admin_role`, `is_active`).

### 2. Multi-Role Human Support
A single human auth user may possess multiple application roles (e.g., a founder acting as Customer, Personnel, and Admin). However, **every operational command requires explicit role context in the execution payload**, and audit logs record the specific role used for the action.

---

## D. Roles & Permissions

Cerelo V1 uses a lean, 3-tier Role-Based Access Control (RBAC) structure with discrete granular permissions:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              CERELO V1 ROLE & PERMISSION TAXONOMY                      │
├─────────────────┬─────────────────────────────────┬────────────────────────────────────┤
│ Role            │ Primary Operational Purpose     │ Permission Scope                   │
├─────────────────┼─────────────────────────────────┼────────────────────────────────────┤
│ 1. CUSTOMER     │ Request, track, share, & receive│ `shipment.create`, `shipment.cancel│
│                 │ intercity parcels.              │ _precustody`, `shipment.read_owned`│
│                 │                                 │ `shipment.share`, `delivery.confirm│
│                 │                                 │ _receipt`                          │
├─────────────────┼─────────────────────────────────┼────────────────────────────────────┤
│ 2. PERSONNEL    │ Execute physical field handoffs,│ `pickup.attend`, `parcel.inspect`, │
│                 │ batching, & doorstep delivery.  │ `parcel.confirm`, `payment.collect`│
│                 │                                 │ `batch.build`, `batch.onboard`,    │
│                 │                                 │ `reconcile.scan`, `delivery.mark`  │
├─────────────────┼─────────────────────────────────┼────────────────────────────────────┤
│ 3. ADMIN        │ Operations oversight, exception │ `ops.view_all`, `incident.resolve`,│
│                 │ management, pricing, & audit.   │ `pricing.manage`, `personnel.manage│
│                 │                                 │ `audit.read`, `record.override`    │
└─────────────────┴─────────────────────────────────┴────────────────────────────────────┘
```

---

## E. Resource-Based Authorization

Role assignment alone does NOT grant access to a resource. Authorization requires establishing a valid **Resource Relationship**:

### 1. Shipment Access Relationships
A Customer is authorized to access a `Shipments` record ONLY if one of these conditions is true:
1. **Sender Relationship:** `shipments.sender_customer_id == auth.uid()`
2. **Linked Receiver Relationship:** `shipments.receiver_customer_id == auth.uid()`
3. **Shared Token Holder:** The request includes a valid, unexpired `share_tokens` token for that shipment (grants restricted projection view only).

### 2. Personnel Operational Scope
A Personnel user is authorized to perform operational actions on a parcel or batch ONLY if:
1. `personnel.is_active == true`.
2. The parcel/batch is within the Personnel's assigned operating city/hub (or assigned delivery task queue).

---

## F. Customer Authorization

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              CUSTOMER AUTHORIZATION MATRIX                             │
├───────────────────┬─────────────────────────────────┬──────────────────────────────────┤
│ Customer Sub-Role │ Allowed Actions                 │ Prohibited Actions               │
├───────────────────┼─────────────────────────────────┼──────────────────────────────────┤
│ Sender            │ Create request, cancel before   │ Confirm parcel, collect payment, │
│                   │ pickup, view sent tracking,     │ build batch, onboard batch,      │
│                   │ share link, receive notifications│ mark delivered, edit price.     │
├───────────────────┼─────────────────────────────────┼──────────────────────────────────┤
│ Receiver          │ View incoming tracking, claim   │ Cancel shipment, edit pickup     │
│                   │ shipment via phone verification,│ address, modify payment split,   │
│                   │ tap optional "Confirm Receipt". │ mark operational delivery.       │
├───────────────────┼─────────────────────────────────┼──────────────────────────────────┤
│ Shared Viewer     │ View sanitized tracking status  │ View full PII, view payment logs,│
│ (Unauthenticated) │ timeline & city names only.     │ perform state changes.           │
└───────────────────┴─────────────────────────────────┴──────────────────────────────────┘
```

---

## G. Personnel Authorization

### 1. Operational Scope Controls
Personnel access is restricted by operational context:
* **Pickup Phase:** Personnel assigned to `Kano Hub` can view and accept pickup tasks originating in Kano.
* **Hub / Batching Phase:** Personnel can build batches only for corridors originating at their assigned hub.
* **Destination Phase:** Personnel at `Katsina Hub` can scan and reconcile batches arriving at Katsina Hub.

### 2. Customer PII Access Scoping
Personnel are granted access to Customer phone numbers and street addresses **ONLY for active assigned tasks** (e.g., performing pickup or doorstep delivery). Personnel CANNOT browse unassigned historical customer address directories.

---

## H. Admin Authorization

### 1. Scoped Administrative Capabilities
Admin users operate with broad operational oversight but remain bounded by safety guardrails:
* **Operations Manager:** Monitors corridors, resolves incident records, overrides batch discrepancies.
* **Support Specialist:** Assists customers with address or receiver phone updates prior to transit.
* **Super Admin:** Manages Personnel accounts, updates corridor price tables, views security audit logs.

### 2. Audit Enforcement for Overrides
Admin overrides (e.g. correcting a recorded payment or updating a receiver phone number post-verification) CANNOT silently mutate database rows. Overrides require an explicit `reason` parameter and generate an immutable `audit_logs` record.

---

## I. Authentication Security

1. **Google OAuth 2.0:** Validates OAuth ID tokens server-side via Supabase Auth. Prevents client token forging.
2. **Email Authentication:** Uses secure password authentication or Magic Link OTP. Passwords hashed using `argon2` or `bcrypt` managed by Supabase Auth.
3. **Session Revocation:** Deactivating a user in `customers`, `personnel`, or `admin_users` immediately revokes API access via RLS database checks.
4. **Account Linking:** Linking a Receiver to a shipment requires matching the verified E.164 phone number associated with the authenticated customer account.

---

## J. MFA Decision

* **Customer Mobile App:** MFA is **NOT REQUIRED** for V1 (optimizes onboarding speed for low-friction shipment requests).
* **Personnel Mobile App:** MFA is **NOT REQUIRED** for V1 (reduces operational friction for field staff in high-speed market environments; security enforced via rapid Admin account deactivation and hardware device binding).
* **Admin Web Panel:** MFA is **STRONGLY RECOMMENDED** for V1 Admin accounts (protects administrative system controls and pricing configuration).

---

## K. Shipment Access Rules

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              SHIPMENT RESOURCE ACCESS MATRIX                           │
├──────────────────────────────┬──────────────┬──────────────┬──────────────┬────────────┤
│ Requester Context            │ Full Detail  │ Status Only  │ Masked PII   │ Prohibited │
├──────────────────────────────┼──────────────┼──────────────┼──────────────┼────────────┤
│ Authenticated Sender         │      ✓       │      —       │      —       │     —      │
│ Authenticated Linked Receiver│      ✓       │      —       │      —       │     —      │
│ Valid Shared Link Holder     │      —       │      ✓       │      ✓       │     —      │
│ Assigned Personnel           │      ✓       │      —       │      —       │     —      │
│ Unassigned Personnel         │      —       │      —       │      —       │     ✓      │
│ Admin / Operations           │      ✓       │      —       │      —       │     —      │
│ Unauthenticated Stranger     │      —       │      —       │      —       │     ✓      │
└──────────────────────────────┴──────────────┴──────────────┴──────────────┴────────────┘
```

---

## L. Parcel Access Rules

* **Customer Access:** Senders and Receivers access parcel details indirectly through their parent `Shipments` authorization.
* **Personnel Scanning Access:** Scanning a Parcel QR Code (`parcel_qr_token`) allows authorized Personnel to resolve the parcel record and execute valid state transitions for their active hub context.
* **Public QR Protection:** Unauthenticated scans of a physical Parcel QR yield an opaque token that returns NO raw customer PII.

---

## M. Batch Access Rules

* **Personnel Access Only:** `Batches` and `BatchMemberships` are strictly internal operational entities.
* **Creation & Confirmation:** Personnel can create and confirm batches for their assigned origin hub.
* **Onboarding Execution:** Only Personnel assigned to the origin hub can mark a batch `ONBOARDED`.
* **Destination Scanning:** Only Personnel assigned to the destination hub can receive and reconcile arriving batch QRs.
* **Customer Isolation:** Customers CANNOT view batch numbers, batch QRs, or internal batch manifests.

---

## N. Payment Access Rules

1. **Obligation Visibility:** Senders see full price breakdowns and expected payment obligations. Receivers see their specific required payment obligation (for `RECEIVER_PAYS` or `SPLIT_PAYMENT`).
2. **Collection Recording Authority:** ONLY active Personnel assigned to the pickup or delivery task can record a cash/transfer payment. Customers CANNOT mark payments as collected.
3. **Price Protection:** Personnel CANNOT change the authoritative delivery price while recording a collection. Price adjustments MUST occur via the formal `PARCEL_SIZE_CORRECTED` RPC.

---

## O. Delivery Completion Security

```
                             [OUT_FOR_DELIVERY]
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
    [PERSONNEL MARK DELIVERED]           [RECEIVER CONFIRMATION]
    • Operational Completion             • Optional Endorsement
    • Requires Assigned Personnel        • Requires Authenticated Receiver
    • Requires Payment Collected         • Does NOT block order closure
    • Sets status to DELIVERED           • Logs customer receipt timestamp
```

* Operational delivery completion is strictly controlled by assigned Personnel. Receiver app confirmation acts as an optional customer endorsement and does not block operational shipment closure.

---

## P. Delivery Code Security

* **Format:** Non-sequential 8-character string (`CRL-8F2K-9P3N`).
* **Entropy:** Cryptographically random generation via `pgcrypto` providing > 2 billion combinations.
* **Enumeration Defense:** Public lookup endpoints are rate-limited to **5 requests/minute per IP address**. Failed lookups return generic error messages (`"Shipment Reference Unavailable"`) without revealing whether the code exists.

---

## Q. QR Security

* **No Plaintext PII:** Parcel QRs and Batch QRs encode opaque, cryptographically signed tokens (JWS) containing UUID references (`{"pid": "uuid", "sig": "signature"}`).
* **Signature Verification:** Server verifies the token signature on every scan request. Tampered or forged QR payloads are rejected.
* **Physical Photo Defense:** Photographing a QR label yields only an opaque string. Exercising operational actions via that string requires an authenticated, active Personnel session.

---

## R. Shared-Link Security

* **Token Format:** 32-character cryptographically random URL token (`https://cerelo.app/track/{token}`).
* **Expiration & Revocation:** Tokens expire automatically after 30 days. Senders can tap "Revoke Share Link" in app to instantly invalidate a token.
* **Restricted Data Projection:** Shared tracking links return ONLY: (1) Delivery Code, (2) Current Status Milestone, (3) Origin & Destination City names, (4) Masked Receiver Name (`Amina M.***`). Full street addresses and phone numbers are scrubbed.

---

## S. Data Visibility Matrix

| Data Field | Sender | Receiver | Shared Viewer | Personnel (Assigned) | Admin |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Delivery Code** | Full | Full | Full | Full | Full |
| **Sender Full Name** | Full | Full | Masked | Full | Full |
| **Sender Phone Number** | Full | Masked | Hidden | Full | Full |
| **Pickup Street Address** | Full | Hidden | Hidden | Full | Full |
| **Receiver Full Name** | Full | Full | Masked | Full | Full |
| **Receiver Phone Number** | Full | Full | Hidden | Full (Task Only) | Full |
| **Destination Address** | Full | Full | Hidden | Full (Task Only) | Full |
| **Parcel Category / Description**| Full | Full | Full | Full | Full |
| **Confirmed Parcel Size** | Full | Full | Full | Full | Full |
| **Customer Status Milestone** | Full | Full | Full | Full | Full |
| **Internal Operational State** | Hidden | Hidden | Hidden | Full | Full |
| **Sender Payment Obligation** | Full | Hidden | Hidden | Full | Full |
| **Receiver Payment Obligation** | Hidden | Full | Masked | Full | Full |
| **Payment Collection History** | Full | Full | Hidden | Task Only | Full |
| **Batch Number & Manifest** | Hidden | Hidden | Hidden | Full | Full |
| **Personnel Staff Name** | Display Name| Display Name| Hidden | Full | Full |
| **Audit Logs & System Events** | Hidden | Hidden | Hidden | Hidden | Full |

---

## T. Authorization Matrix

| Action / Command | Sender | Receiver | Shared Viewer | Personnel | Admin | System |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Create Shipment Request** | Allowed | Prohibited | Prohibited | Prohibited | Prohibited | Prohibited |
| **View Shipment Details** | Owned Only | Linked Only | Restricted | Assigned | Allowed | Allowed |
| **Cancel Request (Pre-pickup)** | Owned Only | Prohibited | Prohibited | Prohibited | Allowed | Prohibited |
| **Share Shipment Link** | Owned Only | Prohibited | Prohibited | Prohibited | Prohibited | Prohibited |
| **Inspect Physical Parcel Size** | Prohibited | Prohibited | Prohibited | Task Scope | Allowed | Prohibited |
| **Correct Parcel Size / Fee** | Prohibited | Prohibited | Prohibited | Task Scope | Allowed | Prohibited |
| **Log Receiver Verification Call**| Prohibited | Prohibited | Prohibited | Task Scope | Prohibited | Prohibited |
| **Record Sender Payment** | Prohibited | Prohibited | Prohibited | Task Scope | Allowed | Prohibited |
| **Execute "Confirm Parcel"** | Prohibited | Prohibited | Prohibited | Task Scope | Prohibited | Prohibited |
| **Print Parcel QR Label** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Scan Parcel QR Code** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Create Batch Container** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Add Parcel to Batch** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Confirm Batch Manifest** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Mark Batch "Onboarded"** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Scan Destination Batch QR** | Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Reconcile Destination Parcel**| Prohibited | Prohibited | Prohibited | Hub Scope | Allowed | Prohibited |
| **Execute "Going for Delivery"** | Prohibited | Prohibited | Prohibited | Task Scope | Prohibited | Prohibited |
| **Record Receiver Payment** | Prohibited | Prohibited | Prohibited | Task Scope | Allowed | Prohibited |
| **Execute "Mark Delivered"** | Prohibited | Prohibited | Prohibited | Task Scope | Prohibited | Prohibited |
| **Receiver Confirm Delivery** | Prohibited | Linked Only | Prohibited | Prohibited | Prohibited | Prohibited |
| **Report Incident / Exception** | Prohibited | Prohibited | Prohibited | Allowed | Allowed | Allowed |
| **Resolve Incident / Override** | Prohibited | Prohibited | Prohibited | Prohibited | Allowed | Prohibited |
| **Manage Pricing Configuration**| Prohibited | Prohibited | Prohibited | Prohibited | Allowed | Prohibited |
| **Manage Personnel Accounts** | Prohibited | Prohibited | Prohibited | Prohibited | Allowed | Prohibited |
| **Read System Audit Logs** | Prohibited | Prohibited | Prohibited | Prohibited | Allowed | Prohibited |

---

## U. Personnel Operational Scope

Operational scope is enforced via a hybrid model combining **Hub Location Assignment** and **Active Task Queues**:
1. **Hub Location Scoping:** Personnel assigned to `Kano Hub` (`assigned_hub_id`) can only create/confirm batches originating in Kano and scan parcels staged at Kano Hub.
2. **Task Queue Scoping:** Personnel accepting a final-mile delivery route receive explicit temporary authorization to update state for parcels in their active `delivery_route_manifest`.

---

## V. Sensitive Command Security Table

| Command Name | Authenticated Actor | Required Permission | Resource Scope | State Precondition | Audit Logged? | Risk Rank |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: |
| `ConfirmParcel` | Personnel | `parcel.confirm` | Assigned Pickup | `REQUESTED` | Yes | HIGH |
| `CorrectParcelSize` | Personnel | `parcel.correct_size` | Assigned Pickup | `REQUESTED` | Yes | MEDIUM |
| `RecordPhysicalPayment`| Personnel | `payment.collect` | Assigned Task | `PENDING` payment | Yes | HIGH |
| `ConfirmBatch` | Personnel | `batch.confirm` | Origin Hub | `DRAFT` batch | Yes | MEDIUM |
| `OnboardBatch` | Personnel | `batch.onboard` | Origin Hub | `CONFIRMED` batch | Yes | HIGH |
| `ReconcileParcel` | Personnel | `reconcile.scan` | Destination Hub | `DESTINATION_RECEIVED`| Yes | HIGH |
| `MarkDelivered` | Personnel | `delivery.mark` | Assigned Route | `OUT_FOR_DELIVERY` | Yes | HIGH |
| `AdminOverrideRecord` | Admin | `admin.override` | System-wide | Any valid state | Yes | BLOCKER |

---

## W. Admin Correction & Override Model

Admin overrides are strictly regulated to prevent silent data corruption:
1. **No Direct SQL Updates:** Admins cannot edit production database rows directly. Overrides MUST execute through audit-logged Admin RPCs (`/functions/v1/admin-override-shipment`).
2. **Mandatory Audit Parameters:** Admin overrides require: (1) `target_resource_id`, (2) `override_type`, (3) `reason_text` (minimum 10 characters), (4) `admin_mfa_token`.
3. **Immutable History Preservation:** Original values are preserved in `audit_logs.old_values`.

---

## X. Role Provisioning & Revocation

1. **No Self-Provisioning:** Customers CANNOT self-upgrade to Personnel or Admin roles.
2. **Personnel Provisioning Flow:** Super Admin creates Personnel profile via Admin Panel → Invites staff email → Assigns `assigned_hub_id` → Server updates `auth.users` app metadata.
3. **Instant Revocation:** Deactivating a staff account sets `personnel.is_active = false`. Supabase Auth RLS immediately denies all API and Edge Function execution for that user ID.

---

## Y. Cash Payment Fraud Controls

To mitigate physical cash handling risks in V1:
* **Workflow Gating:** Personnel CANNOT execute `ConfirmParcel` without recording pickup cash/transfer collection.
* **Server-Expected Amounts:** Personnel app displays exact server-calculated fee. Personnel CANNOT alter expected fee amounts during collection.
* **Append-Only Ledger:** Payment collection records (`payment_collections`) are append-only. Personnel cannot edit or delete collection records once submitted.
* **Daily Reconciliation Reports:** Admin panel generates daily cash collection totals per Personnel staff member.

---

## Z. Audit & Security Logging

### 1. Audit Log Requirements (`audit_logs`)
The following actions MUST generate an immutable `audit_logs` entry:
* User role changes and staff account activation/deactivation.
* Pricing rule updates and corridor configuration changes.
* Admin record overrides and incident resolutions.
* Failed authentication attempts and rate-limit violations.

### 2. Log Privacy & Redaction
Backend application logs MUST automatically sanitize sensitive tokens, passwords, full credit card numbers (N/A in V1), and raw PII before writing to log streams.

---

## AA. Privacy & PII Boundaries

* **Data Minimization:** APIs return ONLY the fields required for the specific user role and screen.
* **No PII in QRs:** QRs encode opaque JWS strings with zero plaintext customer names, addresses, or phone numbers.
* **Masked Displays:** Public shared tracking pages mask names (`Amina M.***`) and conceal full street addresses.

---

## AB. Rate Limiting & Abuse Prevention

| Endpoint / Action | Rate Limit Threshold | Action Upon Exceeding |
| :--- | :--- | :--- |
| **Delivery Code Public Lookup** | 5 requests / min / IP | Block IP for 15 minutes (`429 Too Many Requests`) |
| **Share Link Generation** | 10 links / hour / User | Block request (`429 Too Many Requests`) |
| **Customer Shipment Request** | 5 requests / hour / User | Flag account for spam review |
| **Personnel Scanner RPCs** | 120 scans / min / User | Temporary 1-minute scanner throttle |

---

## AC. Session & Device Security

* **Mobile App Sessions:** JWT access tokens expire after 1 hour; automatically refreshed via secure refresh tokens stored in OS-backed secure storage (`FlutterSecureStorage` using Android Keystore / iOS Keychain).
* **Admin Web Sessions:** Inactive Admin web sessions expire after 30 minutes of inactivity. Mandatory re-authentication required for sensitive Admin overrides.

---

## AD. Storage & File Security

* **Private Storage Buckets:** All QR label files (`qr-labels/`) and operational documents are stored in private Supabase Storage buckets.
* **Signed URL Access:** Mobile apps fetch temporary signed URLs (`expiresIn = 60 seconds`) to download label PDF assets for printing. Direct public bucket access is BLOCKED.

---

## AE. Deep-Link Security

* Incoming deep links (`https://cerelo.app/track/{token}`) treat the token parameter as untrusted input.
* The app passes the token to the server RPC `/functions/v1/resolve-share-token`. The server validates token expiration and revocation status before returning sanitized tracking JSON.

---

## AF. Offline / Connectivity Security

* **No Offline Custody Changes:** Custody-changing actions (`ConfirmParcel`, `OnboardBatch`, `MarkDelivered`) CANNOT complete locally while offline. The app displays `"Action Pending Server Confirmation"`.
* **Server-Validated Retry Queue:** Queued offline requests are executed via idempotent RPCs when connectivity returns. If server validation fails (e.g. state changed while offline), the local queued action is rejected and flagged for Personnel review.

---

## AG. Environment & Secrets Security

1. **Environment Isolation:** Separate Supabase projects and GCP/Firebase console projects for `Development`, `Staging`, and `Production`.
2. **Zero Code Secrets:** Secrets (Supabase Service Role Key, FCM Server Keys, Termii SMS Tokens) are stored exclusively in Supabase Vault / Edge Function Environment Variables.
3. **No Production Access in Dev:** Development environments use synthetic seed datasets only.

---

## AH. Security Invariants

1. **No Unauthenticated State Mutations:** NO state transition or payment collection can occur without a valid authenticated user token.
2. **Client Un-Trust Invariant:** Mobile clients can NEVER update lifecycle status columns directly.
3. **Custody Immutability:** Custody transfer events (`custody_events`) can NEVER be updated or deleted.
4. **Data Isolation Invariant:** Customers can NEVER view shipments where they are neither Sender, Receiver, nor holding a valid share token.
5. **No Code Backdoors:** Universal passwords, master OTPs, or hard-coded founder email bypasses are strictly forbidden.

---

## AI. Security Threat Model

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              CERELO V1 THREAT MODEL                                    │
├─────────────────────────┬──────────────────────────────────┬───────────────────────────┤
│ Threat Vector           │ Potential Impact                 │ Server Security Mitigation│
├─────────────────────────┼──────────────────────────────────┼───────────────────────────┤
│ 1. BOLA / IDOR Attack   │ Attacker modifies another user's │ PostgreSQL RLS policies   │
│                         │ shipment state via API parameters│ enforce ownership context.│
├─────────────────────────┼──────────────────────────────────┼───────────────────────────┤
│ 2. Delivery Code Guess  │ Attacker enumerates codes to view│ Non-sequential random code│
│                         │ customer delivery timelines.     │ + 5 req/min rate limit.   │
├─────────────────────────┼──────────────────────────────────┼───────────────────────────┤
│ 3. Personnel Cash Fraud │ Personnel collects cash but logs │ Workflow gating blocks    │
│                         │ uncollected to steal funds.      │ handover without payment. │
├─────────────────────────┼──────────────────────────────────┼───────────────────────────┤
│ 4. Stolen Staff Phone   │ Thief uses active staff session  │ Instant account freeze in │
│                         │ to alter operational state.      │ Admin Panel revokes JWT.  │
├─────────────────────────┼──────────────────────────────────┼───────────────────────────┤
│ 5. QR Photo Forgery     │ Attacker photographs label to    │ QR encodes opaque token;  │
│                         │ forge operational scans.         │ actions require staff JWT.│
└─────────────────────────┴──────────────────────────────────┴───────────────────────────┘
```

---

## AJ. Security Risk Register

### 1. Personnel Cash Collection Fraud — [RANK: HIGH]
* **Risk:** Personnel collects physical cash from Sender/Receiver but fails to record it in app or records a lower amount.
* **Mitigation:** Workflow gating (cannot confirm parcel or deliver without recording payment), server-calculated expected amounts, daily cash reconciliation reports.

### 2. Delivery Code Enumeration — [RANK: MEDIUM]
* **Risk:** Scripted brute-force attempts to guess 8-character Delivery Codes.
* **Mitigation:** High-entropy random code generation (`pgcrypto`), strict 5 req/min rate limiting per IP, sanitized response payloads.

### 3. Compromised Staff Mobile Device — [RANK: MEDIUM]
* **Risk:** Lost or stolen Personnel smartphone used to falsify delivery states.
* **Mitigation:** Instant account deactivation via Admin Panel revokes session immediately; 1-hour JWT token expiration.

---

## AK. Security Testing Requirements

Before V1 production release, the codebase MUST pass automated security tests verifying:
1. **Authentication Tests:** Unauthenticated requests to protected RPCs return `401 Unauthorized`.
2. **Authorization & IDOR Tests:** Customer A attempting to access Customer B's shipment ID returns `403 Forbidden`.
3. **State Machine Bypasses:** Attempting to call `MarkDelivered` on a shipment in `REQUESTED` status returns `400 Bad Request`.
4. **Rate Limit Verification:** Exceeding 5 Delivery Code lookups in 1 minute returns `429 Too Many Requests`.
5. **RLS SQL Policies:** `pgTAP` unit tests verify row-level isolation across Customer, Personnel, and Admin roles.

---

## AL. RLS / Backend Enforcement Strategy

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY ENFORCEMENT LAYERS                               │
├──────────────────────────┬─────────────────────────────────────────────────────────────┤
│ Enforcement Layer        │ Security Responsibilities                                   │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 1. PostgreSQL RLS        │ Read isolation (SELECT queries), blocking direct table      │
│                          │ INSERT/UPDATE/DELETE for client roles.                      │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 2. Deno Edge Functions   │ Business logic validation, state machine preconditions,     │
│    & PL/pgSQL RPCs       │ notification triggers, atomic multi-table transactions.     │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 3. Database Constraints  │ Foreign keys, non-negative monetary checks, unique indexes. │
└──────────────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## AM. Security Guardrails for AI Coding Agents

AI coding agents (Claude, Gemini, Antigravity) developing Cerelo V1 MUST obey these non-negotiable rules:
1. ❌ **NEVER disable Row Level Security (RLS)** on any table in migrations.
2. ❌ **NEVER use the Supabase Service Role Key** inside Flutter mobile or Next.js client code.
3. ❌ **NEVER hard-code Admin bypasses** or founder email conditionals (`if email == "admin@cerelo.com"`).
4. ❌ **NEVER convert Delivery Codes to sequential integers** for convenience.
5. ❌ **NEVER create direct client UPDATE paths** for shipment lifecycle statuses.

---

## AN. Decisions That Become Locked

1. Security follows a Zero-Trust Client Model—all state transitions and payments are server-authoritative.
2. Identifiers (Delivery Code, QR tokens) convey NO operational privilege without authenticated JWT checks.
3. RLS policies combined with PL/pgSQL RPC functions enforce 100% of data access and state transitions.
4. Admin overrides require explicit reasons and generate immutable `audit_logs` entries.
5. PII is scrubbed from public tracking views and omitted from QR payloads.

---

## AO. Open Security Questions

*(No blocking open security questions remain; security contract fully specifies V1 operations).*

---

## AP. Security Definition of Done

**DECLARATION:** The Security, RBAC & Data Access Architecture for Cerelo V1 is **COMPLETE, DECISIVE, AND LOCKED**.

The project is fully prepared to proceed to:
> **Prompt 7 — Cerelo Repository & Development Foundation**

---
*End of Cerelo V1 Security, RBAC & Data Access Architecture Specification.*
