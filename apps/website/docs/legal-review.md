# CERELO V1 — Legal, Privacy & Data-Processing Review

> **Document Status**: INTERNAL COMPLIANCE DRAFT — FOR MANAGEMENT & LEGAL COUNSEL REVIEW  
> **Applicable Regimes**: Nigeria Data Protection Act 2023 (NDPA), NDPA General Application and Implementation Directive (GAID 2025), Federal Competition and Consumer Protection Act 2018 (FCCPA), Nigerian Postal Services Act (Cap N127 LFN 2004) / Courier & Logistics Regulations.  
> **Classification Framework**:
> - `[VERIFIED FACT]`: Proven by actual repository code, database schema, or locked V1 product freeze.
> - `[CURRENT LAW / REGULATORY REQUIREMENT]`: Grounded in authoritative Nigerian legislation or published regulatory guidance.
> - `[CERELO MANAGEMENT DECISION REQUIRED]`: Commercial or operational policy choice requiring executive sign-off.
> - `[LEGAL COUNSEL REVIEW REQUIRED]`: Legal interpretation or contractual drafting requiring formal legal counsel opinion.
> - `[IMPLEMENTATION REQUIRED]`: Technical, operational, or communication channel capability that must be built before launch.
> - `[UNKNOWN]`: Requires additional empirical data or external verification.

---

## 1. Executive Summary & Core Principles

CERELO V1 provides intercity door-to-door parcel delivery coordination on the **Kano ↔ Katsina corridor** in Nigeria. `[VERIFIED FACT]`

The platform enforces the core privacy principle:
$$\text{OMIT} > \text{MASK} > \text{EXPOSE}$$

Under no circumstances does CERELO claim "full legal compliance", "official NDPC certification", or "statutory licensing" without verified formal documentation. `[VERIFIED FACT]`

---

## 2. Comprehensive Data-Processing Inventory

| Data Category | Source | Purpose | Who Accesses It | Storage & Location | Retention Basis | External Processors | Public Exposure | Status Classification |
|:---|:---|:---|:---|:---|:---|:---|:---|:---|
| **Customer Full Name** | Direct input (Registration) | Account identification, dispatch coordination | Sender, Assigned Personnel, Ops Admin | Supabase PostgreSQL (`customers.full_name`) | Account lifetime `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Zero public exposure) | `[VERIFIED FACT]` |
| **Customer Phone Number** | Direct input (Registration) | Authentication, field dispatch, SMS alerts | Assigned Personnel, Ops Admin | Supabase PostgreSQL (`customers.phone_number`) | Account lifetime `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Zero public exposure) | `[VERIFIED FACT]` |
| **Customer Email** | Direct input / Google OAuth | Passwordless OTP sign-in, transactional notices | Customer, Ops Admin | Supabase Auth (`auth.users.email`), Resend | Account lifetime `[PENDING RETENTION SCHEDULE]` | Supabase Auth, Resend (SMTP) | **NO** | `[VERIFIED FACT]` |
| **Google Identity UID** | Google OAuth (`openid`) | Federated sign-in authentication | Auth engine only | Supabase Auth (`auth.identities`) | Account lifetime | Google Identity, Supabase | **NO** | `[VERIFIED FACT]` |
| **Business Name** | Business registration | Commercial profile, merchant pickup record | Personnel, Ops Admin | Supabase PostgreSQL (`customers.business_name`) | Account lifetime `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** | `[VERIFIED FACT]` |
| **Sender Pickup Address** | Shipment creation | Doorstep parcel collection by Personnel | Assigned Personnel, Ops Admin | Supabase PostgreSQL (`shipments.sender_pickup_address_snapshot`) | Custody record `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Only city shown publicly) | `[VERIFIED FACT]` |
| **Receiver Name** | Sender input during booking | Handover verification at recipient doorstep | Assigned Delivery Personnel, Ops Admin | Supabase PostgreSQL (`shipments.receiver_name_snapshot`) | Custody record `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Zero public exposure) | `[VERIFIED FACT]` |
| **Receiver Phone Number** | Sender input during booking | Delivery arrival call, account linking | Assigned Delivery Personnel, Ops Admin | Supabase PostgreSQL (`shipments.receiver_phone_snapshot`) | Custody record `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Zero public exposure) | `[VERIFIED FACT]` |
| **Receiver Delivery Address** | Sender input during booking | Final-mile doorstep navigation & handover | Assigned Delivery Personnel, Ops Admin | Supabase PostgreSQL (`shipments.receiver_delivery_address_snapshot`) | Custody record `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Only city shown publicly) | `[VERIFIED FACT]` |
| **Delivery Instructions & Landmarks** | Sender booking input | Field navigation by Personnel | Assigned Personnel, Ops Admin | Supabase PostgreSQL (`shipments.delivery_instructions`, `landmark`) | Active delivery + dispute window | Supabase | **NO** | `[VERIFIED FACT]` |
| **Delivery Code** | System assigned at pickup (`CRL-XXXX-XXXX`) | Custody verification, public milestone tracking | Sender, Receiver, Personnel, Public | Supabase PostgreSQL (`shipments.delivery_code`) | Permanent immutable ledger | Supabase | **YES** (Non-secret identifier) | `[VERIFIED FACT]` |
| **Share Token** | Customer share action | Read-only web tracking link | Share recipient | Supabase PostgreSQL (`share_tokens.token`) | 30 days or manual revocation | Supabase | **YES** (Authorized link) | `[VERIFIED FACT]` |
| **Operational Custody Events** | Personnel barcode/QR scan, app action | Chain of custody, auditability, dispute resolution | Participants (own items), Personnel, Admins | Supabase PostgreSQL (`operational_events`) | Permanent immutable ledger | Supabase | **NO** (Only safe milestone types shown publicly) | `[VERIFIED FACT]` |
| **Payment Obligations & Receipts** | Shipment booking & physical collection | Physical cash obligation tracking, driver reconciliation | Sender, Receiver, Personnel, Finance Admin | Supabase PostgreSQL (`payment_obligations`) | Financial audit `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** (Zero payment info in public tracking) | `[VERIFIED FACT]` |
| **Device FCM Push Tokens** | Mobile app initialization | Background operational notifications | Notification Outbox worker | Supabase PostgreSQL (`user_devices.fcm_token`) | Device active lifetime | Firebase Cloud Messaging (Google) | **NO** | `[VERIFIED FACT]` |
| **Incident Reports** | Personnel / Admin input | Damaged/lost parcel investigation | Ops Admin, Super Admin | Supabase PostgreSQL (`incidents`) | Claim resolution `[PENDING RETENTION SCHEDULE]` | Supabase | **NO** | `[VERIFIED FACT]` |
| **Admin Audit Logs** | Internal staff actions | Fraud detection, security governance | Super Admin only | Supabase PostgreSQL (`admin_audit_logs`) | Permanent immutable audit | Supabase | **NO** | `[VERIFIED FACT]` |

---

## 3. Lawful Bases for Processing (NDPA Section 25)

The proposed lawful bases under the Nigeria Data Protection Act 2023 are itemized below for formal legal counsel review `[LEGAL COUNSEL REVIEW REQUIRED]`:

1. **Performance of a Contract (NDPA Section 25(1)(b))**:
   - Primary basis for sender registration, shipment creation, parcel pickup, middle-mile corridor transit, and doorstep delivery.
   - Processing is necessary to execute the logistics service requested by the user.

2. **Legitimate Interests (NDPA Section 25(1)(f))**:
   - **Receiver Data**: Senders provide recipient details (name, phone, address) to enable delivery. Because recipients may not hold a pre-existing account, processing is conducted under legitimate interests to execute the sender's delivery instruction and coordinate arrival.
   - **Platform Security & Fraud Prevention**: Role-based access controls, session integrity, and immutable audit logs.

3. **Legal & Regulatory Obligations (NDPA Section 25(1)(c))**:
   - Maintaining financial collection records and chain-of-custody logs to satisfy applicable commercial, tax, and courier regulations.

4. **Authentication & User Requests**:
   - Utilizing passwordless Email OTP or Google OAuth federated sign-in to authenticate users upon their direct request. *(Note: Authentication mechanism must be distinguished from the substantive legal basis for service provision).* `[LEGAL COUNSEL REVIEW REQUIRED]`

---

## 4. Cloud Infrastructure & Third-Party Processors

| Processor | Role & Architecture | Data Processed | Physical Hosting Location | Cross-Border Transfer Status |
|:---|:---|:---|:---|:---|
| **Supabase, Inc.** | Encrypted Cloud Database (PostgreSQL), Auth, Storage | All customer profiles, shipments, events, auth tokens | AWS Ireland (`eu-west-1`), Ireland (`plsoyomwoqysharmuddl`) `[VERIFIED FACT — confirmed via Supabase CLI projects list]` | `[REQUIRES CROSS-BORDER TRANSFER REVIEW]` |
| **Resend, Inc.** | Transactional Email Delivery (Passwordless OTPs) | Email address, 6-digit OTP code | US Cloud Infrastructure `[VERIFIED FACT]` | `[REQUIRES CROSS-BORDER TRANSFER REVIEW]` |
| **Google LLC** | Google OAuth Federated Sign-in, Firebase Cloud Messaging (FCM) | Name, Email, OAuth UID, FCM Device Token | Global Cloud Infrastructure `[VERIFIED FACT]` | `[REQUIRES CROSS-BORDER TRANSFER REVIEW]` |
| **Vercel, Inc.** | Public Website Hosting & Edge Routing | HTTP requests, Client IP (transient edge routing) | Global Edge Network `[VERIFIED FACT]` | `[REQUIRES CROSS-BORDER TRANSFER REVIEW]` |

---

## 5. Cross-Border Data Transfer Analysis (NDPA Chapter 5)

- **Technical Fact**: Production cloud hosting (Supabase Ireland/AWS eu-west-1, Resend US, Google Global, Vercel Global) involves processing outside Nigeria. `[VERIFIED FACT — confirmed via Supabase CLI]`
- **Statutory Framework**: NDPA Sections 41–43 and GAID 2025 require:
  1. An adequate level of data protection in the recipient jurisdiction; OR
  2. Appropriate contractual safeguards (e.g. Data Processing Agreements incorporating standard clauses approved under Nigerian law); OR
  3. Processing necessary for the performance of a contract between the data subject and controller. `[CURRENT LAW / REGULATORY REQUIREMENT]`
- **Action Required**: Management and legal counsel must evaluate adequacy classifications and execute DPAs with Supabase, Resend, Google, and Vercel. `[CERELO MANAGEMENT DECISION REQUIRED]`

---

## 6. Retention Principles vs. Immutable Operational Ledger

- **Immutable Ledger Fact**: Custody transfer events (`public.operational_events`) are recorded in an append-only ledger to maintain parcel traceability and resolve historical disputes. `[VERIFIED FACT]`
- **Data Erasure Reconciliation**: When an account deletion request is processed, personal contact information in `customers` can be deactivated/anonymized. However, historical operational manifests and delivery codes are retained for regulatory auditability. `[LEGAL COUNSEL REVIEW REQUIRED]`
- **Universal 7-Year Claim Removed**: Fixed 7-year claims have been removed from public customer policies. A concrete corporate data retention schedule must be formally drafted and approved by management. `[CERELO MANAGEMENT DECISION REQUIRED]`

---

## 7. Public Tracking Privacy Model

The public tracking RPC (`public.get_public_shipment_tracking`) strictly enforces: `[VERIFIED FACT]`
- `delivery_code` (e.g. `CRL-2B8K-9X4M`)
- `origin_city` (`Kano`) & `destination_city` (`Katsina`)
- `current_status` (e.g. `IN_TRANSIT`)
- Verified milestone timestamps
- `created_at`, `delivered_at`, `cancelled_at`

**Strictly Omitted Personal Identifiers**:
- Sender & Receiver Names: **OMITTED**
- Contact Phone Numbers: **OMITTED**
- Exact Street Addresses: **OMITTED**
- Package Content Descriptions: **OMITTED**
- Payment Information: **OMITTED**

---

## 8. Summary of Unresolved Decisions (Pre-Deployment Blockers)

1. **Formal Corporate Legal Entity Name**: Registered entity name via Corporate Affairs Commission (CAC) must be confirmed. `[CERELO MANAGEMENT DECISION REQUIRED]`
2. **Registered Physical Office Address**: Physical address for formal legal service in Nigeria. `[CERELO MANAGEMENT DECISION REQUIRED]`
3. **Dedicated Privacy Channel**: Active, monitored mailbox (`privacy@cerelonet.com`). `[IMPLEMENTATION REQUIRED]`
4. **Customer Support Channel**: Active support/dispute desk (`support@cerelonet.com`). `[IMPLEMENTATION REQUIRED]`
5. **Contracting Age Policy**: Formal minimum contracting age policy adopted. `[LEGAL COUNSEL REVIEW REQUIRED]`
6. **Cargo Liability Cap & Claims Policy**: Formal monetary compensation caps and claim filing window approved. `[CERELO MANAGEMENT DECISION REQUIRED]`
7. **Prohibited Items Schedule**: Comprehensive operational restricted items catalog adopted. `[CERELO MANAGEMENT DECISION REQUIRED]`
8. **Failed Delivery & Return Fee SOP**: Protocol for recipient unavailability and return handling approved. `[CERELO MANAGEMENT DECISION REQUIRED]`
