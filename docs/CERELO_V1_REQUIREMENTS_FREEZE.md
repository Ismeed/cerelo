# CERELO V1 SCOPE & REQUIREMENTS FREEZE

> **Document Status:** Authoritative Functional Requirements Specification for Cerelo V1  
> **Pre-requisite Reference:** `CERELO_PRODUCT_CONTEXT.md`  
> **Corridor Scope:** Kano ↔ Katsina, Nigeria  

---

## A. V1 Product Definition

**CERELO V1** is a technology-enabled **intercity door-to-door parcel delivery platform** operating exclusively between **Kano and Katsina, Nigeria** (bi-directional: Kano → Katsina and Katsina → Kano). 

Cerelo V1 coordinates the complete physical journey of a parcel from the sender's doorstep to the receiver's doorstep. Cerelo accepts delivery requests from customers, assigns authorized Cerelo Personnel for physical collection and verification, consolidates parcels into Batches at origin hubs, coordinates middle-mile transport, reconciles parcels at destination hubs, executes final doorstep delivery, and records physical payments.

---

## B. V1 Goals

1. **Validate Corridor Demand:** Prove intercity parcel delivery demand, frequency, and repeat usage among merchants (especially Kantin Kwari Market in Kano) and individuals on the Kano ↔ Katsina corridor.
2. **Validate Controlled Personnel Custody:** Demonstrate that dedicated, authorized Cerelo Personnel can reliably execute first-mile pickup, physical verification, batching, destination reconciliation, and final-mile delivery with high reliability and low parcel loss.
3. **Validate Consolidation Economics:** Test the financial viability of middle-mile parcel batching using commercial transport capacity (e.g. passenger car seat bookings) to achieve positive contribution margins.
4. **Build Customer Trust:** Establish customer trust through reliable physical handoffs, mandatory receiver verification calls, status-based tracking transparency, and post-delivery sender confirmation calls.
5. **Establish Baseline Operational SLA & Metrics:** Capture empirical data on pickup speed, hub processing times, transit durations, reconciliation accuracy, and payment collection success rates.

---

## C. Non-Goals

The following capability areas are **explicitly non-goals** for Cerelo V1 and are strictly excluded from the V1 scope freeze:

1. **Intracity Delivery:** No local dispatch, same-city deliveries, or intracity route selection.
2. **Courier Marketplace & Bidding:** No open driver marketplace, independent rider bidding, rider fare counter-offers, or suggested intracity fares (e.g., ₦1,000 fare).
3. **Smart Box Hardware:** No Smart Box containers, IoT seals, GNSS tracking hardware, or electronic locks (deferred to V2).
4. **Real-Time GPS Live Tracking:** No live map polylines, moving vehicle icons, or courier phone location streaming.
5. **Customer Digital Wallet:** No stored-value wallet balances, escrow accounts, or embedded digital payment gateways (Paystack/Flutterwave) in V1.
6. **Merchant ERP & Storefronts:** No inventory management, staff sub-accounts, product catalogues, or sales analytics.
7. **Owned Middle-Mile Fleet:** No Cerelo-owned interstate trucks, buses, or large logistics vehicles.
8. **Automated AI Optimization:** No AI chatbot, machine-learning batch optimization, or dynamic surge pricing algorithms.

---

## D. Actors & Roles

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                CERELO V1 ACTOR TAXONOMY                                │
├────────────────────────┬──────────────────────────────────┬────────────────────────────┤
│ Actor Category         │ Key Operational Scope            │ Primary System Interface   │
├────────────────────────┼──────────────────────────────────┼────────────────────────────┤
│ 1. Customer            │ Create requests, track parcels,  │ Customer Mobile App        │
│                        │ select payment mode, share links │ (3 Tabs: Home, Shipments,  │
│                        │                                  │  Account)                  │
├────────────────────────┼──────────────────────────────────┼────────────────────────────┤
│ 2. Cerelo Personnel    │ Pickup, verify size, call        │ Mobile-First Personnel UI  │
│                        │ receiver, confirm parcel, print  │ (Task queues, QR scanner,  │
│                        │ QR, batch, reconcile, deliver    │ batch builder, doorstep)   │
├────────────────────────┼──────────────────────────────────┼────────────────────────────┤
│ 3. Admin / Operations  │ Monitor corridors, manage users, │ Admin / Operations Panel   │
│                        │ configure prices, audit logs,    │ (Dashboard, exception      │
│                        │ resolve exceptions & disputes    │ console, role controls)    │
└────────────────────────┴──────────────────────────────────┴────────────────────────────┘
```

### 1. Customer
* **Purpose:** Requests intercity parcel deliveries, tracks parcel progress, manages profile, and accesses shared delivery links.
* **Account Structure:** Single Cerelo Customer Account. Role (Sender vs. Receiver) is strictly **shipment-specific**.
* **Major Permissions:** Create shipment requests, view personal sent/received shipments, share shipment link, confirm receipt (optional).
* **Restrictions:** Cannot access operational task queues, confirm parcel custody, create batches, mark middle-mile onboarding, scan operational QRs, or view other customers' shipments.

### 2. Cerelo Personnel
* **Purpose:** Executes ground operations across first-mile, origin hub, middle-mile onboarding, destination hub reconciliation, and final-mile doorstep delivery.
* **Account Structure:** Authorized operational staff user account assigned to operating hubs (Kano Hub, Katsina Hub).
* **Major Permissions:** View assigned pickup/delivery tasks, edit/correct physical parcel size, record receiver verification call, execute "Confirm Parcel", generate/print Parcel QRs and Batch QRs, build/confirm Batches, mark "Batch Onboarded", scan destination QRs, flag reconciliation exceptions, mark "Going for Delivery", record physical payments, mark "Delivered".
* **Restrictions:** Cannot alter pricing configurations, delete audit logs, access system-wide financial reporting, or access unassigned customer account passwords.

### 3. Admin / Operations
* **Purpose:** Provides operational oversight, exceptions management, corridor/pricing configuration, user management, and audit inspection.
* **Account Structure:** Authorized administrative user account with scoped operational permissions.
* **Major Permissions:** View all shipments/parcels/batches, manage Personnel accounts, override exception states, update corridor price tables, inspect audit logs, export operational performance metrics.
* **Restrictions:** Cannot bypass logged custody audit records or silently delete shipment events.

---

## E. Customer App Requirements

### 1. Navigation Architecture (Strictly 3 Primary Tabs)
The Customer Mobile App shall contain exactly three primary navigation areas:
* **Home:** Primary action launcher and active delivery glance view.
* **Shipments:** Historical and real-time tracking list with Sent/Received filters.
* **Account:** Profile management, business details, saved addresses, and support.

### 2. Onboarding Requirements
* **Google Authentication Flow:** `Continue with Google` → OAuth token verification → Select Account Type (`Individual` vs `Business`) → If Business, input required `Business / Shop Name` → Transition to `Home`.
* **Email Authentication Flow:** `Continue with Email` → Provide Full Name + Email credentials → Complete OTP/link email verification → Select Account Type (`Individual` vs `Business`) → If Business, input required `Business / Shop Name` → Transition to `Home`.

### 3. Home Screen Requirements
* **Primary Action:** Prominently display **"Send a Package"** button. Tapping this button MUST proceed directly into the Intercity Shipment Flow without prompting for service type (intracity vs intercity).
* **Active Shipment Summary:** Display lightweight summary cards for active shipments currently in progress (showing status, Delivery Code, and destination city).

### 4. Shipments Screen Requirements
* **Filter Controls:** Provide toggle tabs for **"Parcels Sent"** and **"Parcels Received"**.
* **Shipment Cards:** Display Delivery Code, current status indicator, origin/destination city, receiver/sender name, and creation date.
* **Search / Filter:** Support quick text search by Delivery Code or contact name.

### 5. Account Screen Requirements
* **Profile Info:** Display user name, email, phone number, and account classification (`Individual` or `Business`).
* **Business Info:** Display and allow editing of `Business / Shop Name` if account type is `Business`.
* **Saved Addresses:** Manage saved pickup and delivery addresses for quick entry.
* **Support & Legal:** Provide access to help contact details, privacy policy, and account logout.

---

## F. Shipment Creation Requirements

### 1. Data Collection Fields
To create a valid intercity shipment request, the customer MUST provide:
1. **Pickup Information:** Pickup address string, origin city (Must be Kano or Katsina).
2. **Receiver Information:** Receiver full name, receiver active phone number, delivery address string, destination city (Must be Katsina if origin is Kano; Kano if origin is Katsina).
3. **Parcel Information:** Estimated parcel size selection (`Small`, `Medium`, `Large`), optional parcel description/category text.
4. **Payment Responsibility Selection:** Select exactly one: `Sender Pays`, `Receiver Pays`, or `Split Payment`.
5. **Split Amount (If Split Payment Selected):** Sender inputs the exact amount they will pay; system calculates the receiver's balance based on the total delivery charge.

### 2. Review Before Request
Before submitting, the customer must be presented with a **Shipment Summary Review Screen** showing:
* Sender Pickup Address & Origin City
* Receiver Name, Phone Number, & Destination Address
* Estimated Parcel Size & Description
* Payment Responsibility Mode & Amount Breakdowns (Sender Amount, Receiver Amount, Total Price)
* Clear CTA: **"Submit Request"**

### 3. Submission Outcome
Submitting a request creates a shipment record in `Requested` status. It does NOT register parcel custody, record payment, or guarantee immediate pickup.

---

## G. Parcel Pickup Requirements

### 1. Pickup Task Assignment
Upon request submission, the system registers a pickup task visible to authorized Cerelo Personnel in the origin city.

### 2. Physical Inspection & Size Correction
When Personnel arrives at the sender's location:
* Personnel physically inspects the parcel dimensions and weight.
* If sender selected `Small` but parcel is physically `Medium`, Personnel updates the parcel size in the Personnel app interface.
* **Price Adjustment Rule:** Updating size updates the calculated delivery charge. The revised total, sender amount, and receiver amount are updated on the shipment record and displayed to the sender.

### 3. Mandatory Receiver Verification Call
While physically beside the sender and parcel, Personnel MUST call the receiver's phone number from their phone. Personnel records in the app:
* Receiver answered and confirmed identity.
* Receiver confirmed awareness of incoming parcel and correct destination address.
* Receiver agreed to accept parcel and pay required fee (if `Receiver Pays` or `Split Payment`).
* If receiver cannot be reached after mandatory retries, Personnel flags parcel as `Pickup On Hold - Receiver Unreachable`.

---

## H. Payment Requirements

### 1. Supported Payment Modes
* **Sender Pays (100%):** Full delivery fee collected by Personnel from sender at pickup.
* **Receiver Pays (100%):** Full delivery fee collected by Personnel from receiver at doorstep delivery.
* **Split Payment:** Sender portion collected at pickup; receiver portion collected at delivery.

### 2. Physical Payment Collection & Recording
* Payment is strictly physical cash or direct mobile bank transfer to Cerelo Personnel. No wallet deduction.
* When Personnel receives payment, they MUST record:
  * Amount Collected (₦)
  * Payer Role (`Sender` or `Receiver`)
  * Payment Method (`Cash` or `Bank Transfer`)
  * Collector Personnel ID & Timestamp

### 3. Payment Failure Protocols
* **Pickup Payment Failure (Sender Pays / Split):** If sender cannot pay required amount at pickup, Personnel CANNOT execute "Confirm Parcel". Shipment transitions to `Pickup On Hold - Payment Pending`.
* **Doorstep Payment Failure (Receiver Pays / Split):** If receiver refuses or cannot pay required amount at delivery, Personnel CANNOT hand over parcel or mark "Delivered". Parcel is returned to Destination Hub and status set to `Delivery Failed - Payment Refused`.

---

## I. Parcel Confirmation Requirements

### 1. Pre-Conditions for Parcel Confirmation
Personnel can only trigger **"Confirm Parcel"** when:
1. Physical size inspection is completed and recorded.
2. Receiver verification phone call is logged as successful.
3. Pickup payment is collected and recorded (if `Sender Pays` or `Split`).

### 2. Confirm Parcel Event Outcome
Executing "Confirm Parcel":
* Formally accepts the physical parcel into Cerelo custody.
* Updates customer shipment status to `Parcel Confirmed`.
* Generates unique **Delivery Code** and encrypted **Parcel QR Code**.

### 3. Label Printing & Attachment
* System presents printable **Parcel QR Label** in Personnel app interface.
* Personnel selects label dimensions (e.g. 4x6 thermal or standard sticker sheet).
* Personnel prints label via hub/portable printer and affixes label securely to physical parcel.

---

## J. Batch Requirements

### 1. Batch Definition & Purpose
A **Batch** is an operational digital container representing a consolidated group of physical parcels traveling together on middle-mile transport along a specific corridor (e.g., Kano Hub → Katsina Hub).

```
[Origin Hub] ──> Personnel selects "Create Batch" (Route: Kano -> Katsina)
                      │
                      ├──> Scans Parcel QR 1 ──┐
                      ├──> Scans Parcel QR 2 ──┼──> Manifest Populated (3 Parcels)
                      └──> Enters Code 3 (Fallback) ┘
                      │
                      └──> Taps "Confirm Batch" ──> Generates Batch QR Code
```

### 2. Batch Creation & Building
* Authorized Personnel selects **"Create Batch"** at origin hub, selecting corridor direction.
* Personnel adds parcels to batch by:
  * **Primary Method:** Camera scanning physical **Parcel QR Code**.
  * **Fallback Method:** Typing human-readable **Delivery Code**.

### 3. Membership Validation Rules
The system SHALL reject adding a parcel to a batch if:
* Parcel is already member of another active or onboarded batch.
* Parcel origin/destination does not match batch route.
* Parcel status is not `Parcel Confirmed` or `At Origin Hub`.
* Parcel status is `Delivered`, `Cancelled`, or `Returned`.

### 4. Confirm Batch & Batch QR Generation
* Personnel reviews digital manifest (total parcel count, size breakdown).
* Personnel taps **"Confirm Batch"**. System locks batch manifest and generates unique **Batch QR Code**.
* Personnel prints or displays Batch QR for middle-mile onboarding.

---

## K. Middle-Mile Requirements

### 1. Configurable Transport Assignment
* Consolidated Batches are assigned to middle-mile transport capacity (e.g. reserved commercial passenger car seats like Kwankwasiyya).
* Software records transport metadata (Driver Name, Phone, Vehicle Plate, Capacity Fee ₦) without hard-coding specific transport companies.

### 2. Batch Onboarding Execution
* When physical transport departs origin city, Personnel taps **"Mark Batch Onboarded"**.
* System records onboarding event (Actor ID, Timestamp, Location).
* **Cascading Status Propagation:** All parcels contained within the onboarded batch automatically transition to customer status **`In Transit`**.

---

## L. Destination Reconciliation Requirements

### 1. Batch Receipt at Destination Hub
When middle-mile transport arrives at destination hub, Destination Personnel scans the physical **Batch QR Code** using their camera scanner.

### 2. Item-by-Item Reconciliation Workflow
1. System displays expected manifest list (`N` expected parcels).
2. Personnel scans each arriving parcel's physical **Parcel QR Code** (or enters Delivery Code fallback).
3. System checks off scanned parcel against manifest list.

```
Expected Manifest (3 Parcels):
[✓] Parcel QR 101 ──> Scanned (MATCHED)
[✓] Parcel QR 102 ──> Scanned (MATCHED)
[!] Parcel QR 103 ──> Missing (EXCEPTIONAL FLAG TRIGGERED)
```

### 3. Discrepancy & Reconciliation Rules
* If all expected parcels are scanned and matched: Personnel taps "Reconciliation Complete". Batch status transitions to `Reconciled`; all contained parcels transition to **`Arrived Destination Hub`**.
* If a parcel is missing, extra unexpected parcel arrives, or label is unreadable: System generates an **Exception Record** (flagging specific parcel IDs) and alerts Admin/Operations. Discrepancy MUST be acknowledged before closing batch.

---

## M. Final-Mile Requirements

### 1. Going for Delivery
Destination Personnel selects reconciled parcels for final delivery route and taps **"Going for Delivery"**. System updates associated customer shipment status to **`Out for Delivery`**.

### 2. Doorstep Handover & Delivery Completion
At receiver doorstep, Personnel:
1. Verifies receiver identity.
2. Collects remaining payment (if `Receiver Pays` or `Split`). Records collection in app.
3. Physically hands over parcel.
4. Taps **"Mark Delivered"** in Personnel app. System transitions shipment status to **`Delivered`**.

### 3. Receiver Confirmation (Optional Customer Action)
Receiver can tap **"Confirm Delivery"** on their Customer App. This acts as a customer endorsement record and does not block Personnel's operational delivery completion.

### 4. Mandatory Post-Delivery Sender Call
Immediately post-handover and before leaving receiver doorstep, Personnel MUST call sender to verbally confirm successful delivery. Personnel logs call completion in app. System sends automated digital push/SMS notification to sender.

---

## N. Shipment Tracking Requirements

### 1. Status-Based Tracking Model (No Live GPS)
Tracking is strictly milestone-based. Map polylines, moving GPS icons, and live driver location streams are strictly forbidden.

### 2. Customer-Facing Status Pipeline
The customer app SHALL display exactly these 7 customer-facing statuses:

```
[1. Requested] ──► [2. Parcel Confirmed] ──► [3. At Origin Hub] ──► [4. In Transit]
                                                                          │
[7. Delivered] ◄── [6. Out for Delivery] ◄── [5. Arrived Destination] ◄──┘
```

1. `Requested`: Delivery request submitted by sender.
2. `Parcel Confirmed`: Personnel verified parcel, called receiver, collected pickup payment, accepted custody.
3. `At Origin Hub`: Parcel arrived at origin hub and is awaiting batch consolidation.
4. `In Transit`: Parcel batch onboarded onto middle-mile transport.
5. `Arrived Destination`: Destination hub scanned batch QR and reconciled parcel.
6. `Out for Delivery`: Personnel departed destination hub on final delivery route.
7. `Delivered`: Parcel handed to receiver at doorstep; payment verified.

---

## O. Sharing & Receiver Access Requirements

### 1. Share Link Generation
On any shipment detail page in the Customer App, sender can tap **"Share Shipment"** or **"Copy Link"**. System generates a unique deep-link URL (e.g. `https://cerelo.app/track/{DeliveryCode}`).

### 2. Receiver Link Handling
* **If Cerelo App Installed:** Tapping link opens Cerelo app directly to shipment detail view under "Parcels Received".
* **If Cerelo App NOT Installed:** Tapping link opens web browser tracking landing page displaying shipment status timeline and options to download Cerelo app.

### 3. Privacy & Data Isolation Boundaries
A shared tracking view MUST only display:
* Delivery Code & Current Customer Status Timeline.
* Origin City & Destination City.
* Parcel Description & Size Category.
* Masked Receiver Name (e.g. "Amina M.***").

Shared links MUST NEVER expose:
* Sender profile details, email, or full address.
* Receiver full doorstep address to unauthenticated users.
* Unrelated customer shipments.
* Internal Personnel notes, driver names, or batch IDs.

---

## P. Admin/Operations Requirements

The Admin/Operations web interface shall provide minimal V1 oversight capabilities:
1. **Live Corridor Monitoring:** Overview of active requests, confirmed parcels, batched shipments, and deliveries across Kano ↔ Katsina.
2. **Exception Management Console:** Real-time alert list for reconciliation mismatches, payment failures, unreachable receivers, and damaged parcels. Allows Admin override.
3. **User Management:** Create, activate, deactivate, and assign operating city roles for Cerelo Personnel.
4. **Pricing Configuration:** Manage base delivery pricing tables per corridor and parcel size category.
5. **Audit Log Inspection:** View immutable event history for all custody changes, payment collections, and status transitions.

---

## Q. Notification Requirements

Cerelo V1 shall trigger automated push and/or SMS notifications for the following events:
1. `REQUEST_ACKNOWLEDGED`: Sent to sender when request is submitted.
2. `PARCEL_CONFIRMED`: Sent to sender when Personnel accepts parcel custody.
3. `IN_TRANSIT`: Sent to sender and receiver when batch is onboarded.
4. `ARRIVED_DESTINATION`: Sent to receiver when parcel passes destination reconciliation.
5. `OUT_FOR_DELIVERY`: Sent to receiver when Personnel starts final delivery route.
6. `DELIVERED`: Sent to sender when parcel is handed over at doorstep.
7. `EXCEPTION_ALERT`: Sent to sender/receiver if delivery is delayed or requires action.

---

## R. Exception Requirements

```
┌─────────────────────────┬──────────────────────────────────┬──────────────────────────────────────────┐
│ Operational Phase       │ Exception Trigger                │ Mandatory System / Workflow Action       │
├─────────────────────────┼──────────────────────────────────┼──────────────────────────────────────────┤
│ 1. Pickup               │ Sender unavailable / address bad │ Log "Pickup Failed", reschedule or cancel│
│                         │ Receiver phone unreachable       │ Log "Receiver Unreachable", hold pickup  │
│                         │ Sender refuses pickup payment    │ Cancel pickup, log payment failure       │
├─────────────────────────┼──────────────────────────────────┼──────────────────────────────────────────┤
│ 2. Batching             │ Damaged Parcel QR Code           │ Personnel inputs Delivery Code fallback  │
│                         │ Parcel assigned to wrong route   │ Rejection alert, block batch add         │
├─────────────────────────┼──────────────────────────────────┼──────────────────────────────────────────┤
│ 3. Destination Hub      │ Expected parcel missing on scan  │ Flag parcel "Missing in Transit", alert  │
│                         │ Unexpected extra parcel in batch │ Flag parcel "Unmanifested Arrival"       │
├─────────────────────────┼──────────────────────────────────┼──────────────────────────────────────────┤
│ 4. Doorstep Delivery    │ Receiver unavailable at address  │ Log "Delivery Attempt 1 Failed", return  │
│                         │ Receiver refuses doorstep payment│ Log "Payment Refused", return to hub     │
└─────────────────────────┴──────────────────────────────────┴──────────────────────────────────────────┘
```

---

## S. Security & Privacy Requirements

1. **Role-Based Access Control (RBAC):** Customers cannot invoke Personnel or Admin endpoints. Personnel cannot access Admin system configuration or modify price tables.
2. **Identifier Security:** Delivery Codes and Parcel QRs must use cryptographically random string generation algorithms to prevent sequential code enumeration attacks.
3. **Data Scrubbing:** Shared tracking views must scrub private PII (street addresses, phone numbers, email addresses) for unauthenticated view requests.
4. **Audit Trail Immutability:** Custody transfer records (Pickup, Batch Onboard, Destination Scan, Handover) must record immutable event logs containing `ActorID`, `Action`, `Timestamp`, and `Location`.

---

## T. Metrics/Data Requirements

The V1 system MUST capture discrete database event logs to calculate:
* **Demand:** Request count, request-to-confirmed conversion rate, repeat sender rate.
* **Volume:** Daily parcels by direction (Kano→Katsina vs. Katsina→Kano), average batch size.
* **Revenue:** Daily gross revenue, revenue per parcel, revenue by payment mode.
* **Direct Costs:** Middle-mile transport fee per batch/seat, final-mile operational expenses.
* **Reliability:** Successful delivery rate, reconciliation discrepancy rate, lost/damaged parcel rate.
* **Speed (SLAs):** Request-to-Pickup duration, Pickup-to-Batch duration, Middle-mile transit duration, Destination-to-Doorstep duration, Total Door-to-Door delivery SLA.

---

## U. V1 Functional Requirements Register

### 1. Customer & Account Requirements (`CUS-xxx`)
* **`CUS-001` — Google Onboarding:** The system shall allow new users to register a Customer Account using Google OAuth, collecting account classification (`Individual` or `Business`) and optional `Business / Shop Name`.
* **`CUS-002` — Email Onboarding:** The system shall allow new users to register a Customer Account using Email authentication, collecting Full Name, account classification, and optional `Business / Shop Name`.
* **`CUS-003` — Navigation Structure:** The Customer App interface shall enforce exactly three primary tabs: `Home`, `Shipments`, and `Account`.
* **`CUS-004` — Business Account Profile:** The system shall allow Business accounts to view and update their registered `Business / Shop Name`.

### 2. Shipment Creation Requirements (`SHP-xxx`)
* **`SHP-001` — Intercity Request Entry:** Tapping "Send a Package" on Home shall bypass intracity options and lead directly into the Kano ↔ Katsina intercity shipment flow.
* **`SHP-002` — Required Shipment Data:** The shipment creation form shall validate and capture sender pickup address, origin city, receiver name, receiver phone, destination delivery address, destination city, estimated parcel size, description, and payment mode.
* **`SHP-003` — Corridor Validation:** The system shall strictly enforce supported launch routes (Kano → Katsina or Katsina → Kano) and reject unsupported origin/destination pairs.
* **`SHP-004` — Payment Responsibility Selection:** The sender shall select exactly one payment mode (`Sender Pays`, `Receiver Pays`, or `Split Payment`).
* **`SHP-005` — Split Payment Calculation:** For Split Payment requests, the system shall calculate the receiver's remaining balance based on the total delivery charge minus sender's payment.
* **`SHP-006` — Shipment Review & Submission:** The system shall present a full review screen before submission, creating a shipment in `Requested` status upon submission.

### 3. Pickup & Parcel Confirmation Requirements (`PAR-xxx`)
* **`PAR-001` — Physical Size Correction:** Personnel shall be able to inspect and update the verified parcel size (`Small`, `Medium`, `Large`), automatically recalculating the delivery fee.
* **`PAR-002` — Receiver Verification Call Logging:** Personnel shall record the mandatory pre-pickup receiver verification call result before parcel confirmation is allowed.
* **`PAR-003` — Confirm Parcel Event:** Personnel shall execute "Confirm Parcel" after verification, changing status to `Parcel Confirmed` and generating Parcel QR + Delivery Code.
* **`PAR-004` — Parcel QR Label Generation:** The system shall generate a scannable Parcel QR Code label formatted for thermal/sticker printing in selectable sizes.

### 4. Payment Requirements (`PAY-xxx`)
* **`PAY-001` — Physical Pickup Payment Record:** Personnel shall record physical cash/transfer collected from sender at pickup (for `Sender Pays` or `Split`).
* **`PAY-002` — Physical Doorstep Payment Record:** Personnel shall record physical cash/transfer collected from receiver at doorstep (for `Receiver Pays` or `Split`).
* **`PAY-003` — Payment Failure Gating:** The system shall block "Confirm Parcel" if pickup payment fails, and block "Mark Delivered" if doorstep payment fails.

### 5. Batch & Middle-Mile Requirements (`BAT-xxx`)
* **`BAT-001` — Create Batch:** Personnel shall create a new Batch for a specific corridor route at an origin hub.
* **`BAT-002` — Add Parcel via QR Scan:** Personnel shall add parcels to a batch by camera-scanning physical Parcel QRs.
* **`BAT-003` — Delivery Code Fallback Entry:** Personnel shall be able to manually type a Delivery Code to add a parcel to a batch when QR scanning fails.
* **`BAT-004` — Batch Validation Rules:** The system shall reject duplicate parcel batching, cancelled parcels, delivered parcels, or parcels for wrong routes.
* **`BAT-005` — Confirm Batch & Batch QR:** Personnel shall confirm the batch manifest, triggering unique Batch QR generation.
* **`BAT-006` — Mark Batch Onboarded:** Personnel shall mark confirmed batches as "Onboarded" upon transport departure, propagating `In Transit` status to all contained parcels.

### 6. Reconciliation & Final-Mile Requirements (`REC-xxx` / `DLV-xxx`)
* **`REC-001` — Destination Batch Scan:** Destination Personnel shall scan arriving Batch QRs to load expected parcel manifests.
* **`REC-002` — Item Reconciliation Scan:** Destination Personnel shall scan individual physical Parcel QRs to reconcile received items against the batch manifest.
* **`REC-003` — Discrepancy Flagging:** The system shall automatically flag missing or unmanifested parcels as Exception Records requiring Admin review.
* **`DLV-001` — Going for Delivery:** Personnel shall mark selected reconciled parcels as "Going for Delivery", updating customer status to `Out for Delivery`.
* **`DLV-002` — Personnel Mark Delivered:** Personnel shall record doorstep handover in app, updating status to `Delivered`.
* **`DLV-003` — Mandatory Doorstep Sender Call:** Personnel shall log completion of the mandatory doorstep phone call to sender post-handover.

### 7. Tracking & Access Requirements (`TRK-xxx` / `SEC-xxx`)
* **`TRK-001` — Status-Based Pipeline:** The customer app shall display tracking progress exclusively using the 7 defined milestone statuses without live GPS maps.
* **`TRK-002` — Sent vs Received Filtering:** The Shipments tab shall toggle between `Parcels Sent` and `Parcels Received` based on account role.
* **`SEC-001` — Shipment Deep-Link Sharing:** Senders shall be able to share a tracking deep-link that resolves to sanitized shipment details without exposing private PII.

---

## V. Acceptance Criteria

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              V1 WORKFLOW ACCEPTANCE MATRIX                             │
├──────────────────────────┬─────────────────────────────────────────────────────────────┤
│ Workflow                 │ Key Validation Criteria (Given / When / Then)               │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 1. Customer Onboarding   │ GIVEN a new user selecting Google/Email onboarding,         │
│                          │ WHEN they authenticate & choose Individual or Business,     │
│                          │ THEN account is created and user lands on Home tab.         │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 2. Send a Package        │ GIVEN an authenticated customer on Home tab,                │
│                          │ WHEN they tap "Send a Package" and complete valid form,     │
│                          │ THEN a shipment in 'Requested' status is created.           │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 3. Parcel Verification   │ GIVEN Personnel at sender location,                         │
│                          │ WHEN Personnel inspects size & logs receiver phone call,    │
│                          │ THEN parcel size/fee updates & "Confirm Parcel" unlocks.    │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 4. Batch Onboarding      │ GIVEN confirmed parcels at Origin Hub,                      │
│                          │ WHEN Personnel adds parcels, confirms batch & marks onboard,│
│                          │ THEN all contained parcels update to 'In Transit'.          │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 5. Destination Reconcile │ GIVEN arriving middle-mile Batch at Destination Hub,        │
│                          │ WHEN Personnel scans Batch QR & scans all physical parcels, │
│                          │ THEN missing items trigger alerts & matched items pass.     │
├──────────────────────────┼─────────────────────────────────────────────────────────────┤
│ 6. Doorstep Handover     │ GIVEN Personnel at receiver address with payment collected, │
│                          │ WHEN Personnel taps "Mark Delivered" & logs doorstep call,  │
│                          │ THEN status updates to 'Delivered' & sender is notified.    │
└──────────────────────────┴─────────────────────────────────────────────────────────────┘
```

---

## W. Locked Decisions

The following product decisions are **PERMANENTLY LOCKED** for V1:
1. V1 service is intercity door-to-door parcel delivery ONLY (Kano ↔ Katsina). Intracity delivery is strictly excluded.
2. Independent courier marketplaces, driver bidding, and ₦1,000 fare suggestions are strictly removed.
3. Customer accounts are unified. Sender/Receiver identity is shipment-specific.
4. Customer app navigation is locked to 3 tabs: Home, Shipments, Account.
5. "Send a Package" leads directly into the intercity shipment creation flow.
6. Authorized Cerelo Personnel (not unvetted riders) control pickup, verification, batching, reconciliation, and delivery.
7. Physical parcel size inspection and receiver verification phone calls are mandatory prior to parcel confirmation.
8. Scannable Parcel QRs and human-readable Delivery Codes are generated upon parcel confirmation.
9. Digital Batches (with Batch QRs) replace hardware Smart Boxes in V1.
10. Marking a Batch "Onboarded" propagates customer status to `In Transit`.
11. Tracking is status-based milestone progression only. Live GPS maps are forbidden.
12. Destination hub reconciliation via Parcel QR scanning is mandatory.
13. Payments are physical cash/transfer recorded by Personnel. Digital wallets/escrows are excluded.
14. Personnel calls sender from doorstep post-handover before leaving.

---

## X. Assumptions / Configurable Business Rules

The following parameters are **configurable business variables** and must NOT be hard-coded into UI text or database schemas:
1. **Base Delivery Pricing:** Pricing tiers per parcel size category for Kano ↔ Katsina (e.g. ₦3,000 average revenue hypothesis).
2. **Middle-Mile Capacity Cost:** Transport seat fee (e.g. ₦7,000 Kwankwasiyya car seat hypothesis).
3. **Target Batch Size:** Ideal parcel count per consolidated Batch (~10 parcels hypothesis).
4. **Middle-Mile Provider:** Commercial transport provider identity (Kwankwasiyya vs. alternative operators).
5. **Parcel Size Tiers:** Weight and dimensional boundaries for Small, Medium, and Large categories.
6. **Operating Corridor Tiers:** Ability to add new city pairs in future releases without re-architecting software.

---

## Y. Remaining Founder Decisions

The following unresolved product items require **explicit founder sign-off** prior to Prompt 3:

| # | Issue | Available Options | Recommended Direction | Impact If Unresolved |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **Parcel Size Category Boundaries** | A. Weight-based (e.g. Small <= 3kg, Medium <= 10kg)<br>B. Dimension-based (Shoebox vs Carton) | **Option A (Weight Tiers):** Objective, prevents Personnel size disputes. | Personnel cannot objectively correct sender size selections. |
| **2** | **Split Payment Ratio Rule** | A. Fixed 50/50 split only<br>B. Customizable Sender Amount entry | **Option B (Custom Sender Amount):** Allows sender to pay fixed sum (e.g. ₦1,000) and receiver pays rest. | Senders cannot offer partial shipping subsidies to receivers. |
| **3** | **Doorstep Payment Refusal Protocol** | A. Immediate return to Destination Hub<br>B. Return to Sender in Kano (charging return fee) | **Option A:** Hold at Destination Hub for 24h to allow receiver retry before shipping back. | Stranded parcels at doorstep cause Personnel confusion. |
| **4** | **Delivery Completion Semantics** | A. Personnel "Delivered" mark closes shipment<br>B. Mandatory Receiver app confirmation required | **Option A:** Personnel mark completes delivery; Receiver app tap is optional endorsement. | Deliveries remain unclosed if receivers never open the app. |

---

## Z. Definition of V1 Scope Freeze

### DECLARATION OF SCOPE FREEZE
This document (`CERELO_V1_REQUIREMENTS_FREEZE.md`), together with `CERELO_PRODUCT_CONTEXT.md`, constitutes the **FROZEN FUNCTIONAL REQUIREMENTS CONTRACT FOR CERELO V1**.

#### Scope Governance Rules:
1. **No Unilateral Feature Additions:** Subsequent technical architecture, design, and development prompts MAY refine implementation mechanics, improve UX performance, or fix operational edge cases, but **MUST NOT** introduce new services (e.g., intracity, wallets, Smart Boxes, live GPS, marketplaces).
2. **Operational Ownership Preservation:** The software design must preserve controlled operational custody under Cerelo Personnel.
3. **Configurability Protection:** Business variables (prices, transport fees, size limits) must remain configurable in data structures rather than hard-coded into application logic.

Any deviation from this frozen scope requires an explicit scope amendment approved by the product founders.

---
*End of Cerelo V1 Scope & Requirements Freeze Specification.*
