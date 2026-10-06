# CERELO PRODUCT CONTEXT (V1 MASTER DOCUMENT)

> **Document Status:** Authoritative Product Context for Cerelo V1  
> **Target Launch Corridor:** Kano ↔ Katsina, Nigeria  
> **Primary Service:** Technology-Enabled Intercity Door-to-Door Parcel Delivery  

---

## A. Executive Product Summary

### What Cerelo Is
**CERELO** is a technology-enabled **intercity door-to-door logistics platform and delivery network** operating initially in Nigeria. Cerelo coordinates the entire physical movement of a parcel between cities, removing the burden from customers of independently managing first-mile collection, middle-mile transport, and final-mile delivery.

### The Problem Cerelo Solves
Intercity parcel logistics in Nigeria—particularly for merchants and individuals operating between major commercial hubs—is highly fragmented, manual, and unreliable. Senders currently have to:
* Physically travel to motor parks or arrange independent dispatch riders.
* Negotiate informal delivery fares with transport drivers.
* Repeatedly call middle-mile drivers asking for updates on parcel progress.
* Independently arrange and pay for final-mile collection and delivery at the destination city.

Cerelo solves this by offering a single unified promise: **"Door to door."** Senders request delivery from their doorstep, and Cerelo manages the custody chain until the parcel is physically handed to the receiver at their doorstep.

### Target Audience & Initial Corridor
* **Initial Corridor:** **Kano ↔ Katsina** (Bi-directional support: Kano → Katsina and Katsina → Kano).
* **Primary Target Senders:** Social-commerce merchants operating in and around **Kantin Kwari Market** in Kano (textile/clothing sellers, electronics accessories, WhatsApp/Instagram vendors), SMEs, and individual senders requiring reliable intercity parcel transport.

### Core Operational Distinction
Unlike on-demand rider marketplaces (like Uber/Gokada) or fragmented freight boards, Cerelo V1 relies on **authorized Cerelo Personnel** who control physical parcel pickup, size verification, receiver pre-confirmation, hub batching, destination reconciliation, and doorstep delivery. Independent, unvetted marketplace drivers do not handle Cerelo parcels.

---

## B. V1 Scope

### INCLUDED IN V1
* **Intercity Door-to-Door Delivery:** Exclusively for the Kano ↔ Katsina corridor (both directions).
* **Customer Accounts:** Unified customer account model with Google and Email onboarding.
* **Account Type Selection:** Individual or Business account (collecting Business/Shop Name for Business accounts).
* **Mobile Customer App (3 Navigation Tabs):** Home, Shipments, Account.
* **Intercity Shipment Creation ("Send a Package"):** Sender inputs pickup/delivery details, receiver info, estimated parcel size, description, and selects payment responsibility.
* **Flexible Payment Responsibility:** Sender Pays, Receiver Pays, or Split Payment (physical cash/transfer collected at pickup/delivery).
* **Cerelo Personnel Verification & Handoff:** Physical parcel inspection, size correction, payment mode verification, mandatory live pre-confirmation call to receiver, and formal digital "Confirm Parcel" action.
* **Dual Parcel Identifiers:** Human-readable **Delivery Code** (for manual customer access and fallback entry) and scannable **Parcel QR Code** (for operational tracking).
* **Downloadable & Printable Parcel QR Labels:** Selectable practical label sizing for physical attachment to parcels.
* **Hub Batching Model:** Digital and physical consolidation of parcels into a **Batch** at origin hubs via Parcel QR scanning or manual Delivery Code fallback entry.
* **Batch Manifest & Batch QR Code:** Unique Batch QR generation and digital manifest linking Batch to all contained parcels.
* **Middle-Mile Transport Onboarding:** Operational "Mark Batch Onboarded" action triggering customer-facing "In Transit" status.
* **Status-Based Parcel Tracking:** Milestones (Requested → Parcel Confirmed → At Origin Hub → In Transit → Arrived Destination Hub → Out for Delivery → Delivered).
* **Destination Batch Scanning & Parcel Reconciliation:** Scanning Batch QR, individual Parcel QR scans, manifest verification, and discrepancy flagging.
* **Controlled Final-Mile Delivery:** Destination Personnel triggers "Going for Delivery" (updating status to Out for Delivery), doorstep handover, Personnel marks "Delivered", optional Receiver delivery confirmation.
* **Sender Completion Workflow:** Automated digital notification + mandatory physical phone call from Personnel to sender from receiver's doorstep upon successful handover.
* **Customer Shipment Sharing:** Deep-link / web fallback sharing mechanism for senders to send tracking access to receivers.
* **Operational Admin Oversight:** Internal management of customers, personnel, parcels, batches, and exception logs.

### EXCLUDED FROM V1 (LOCKED SCOPE BOUNDARIES)
* ❌ Intracity / Same-city local parcel dispatch.
* ❌ Courier marketplace / Independent rider bidding / Rider fare negotiation / ₦1,000 suggested fare.
* ❌ Customer wallet / Stored-value balances / Escrow phrasing / Digital payment gateway integration (Paystack, etc.) in V1.
* ❌ Smart Box hardware / Smart Box GPS/GNSS / Smart Box seals (Deferred to V2).
* ❌ Real-time live GPS parcel tracking / Moving map icons / Rider phone location tracking.
* ❌ AI chatbots / Automated AI route optimization / Dynamic surge pricing algorithms.
* ❌ Merchant ERP features / Inventory management / Storefronts / Catalogues / Multi-staff business accounts.
* ❌ Cerelo-owned middle-mile vehicle fleet or motorcycle fleet dependencies.
* ❌ Mandatory delivery OTP / PIN verification at doorstep (unless re-introduced by founders).

---

## C. Customer Account Model

### Unified Customer Account Philosophy
Cerelo does **not** create separate account types for "Senders" and "Receivers". A user registers a single **Cerelo Customer Account**. Their role as Sender or Receiver is strictly **shipment-specific**:
* A merchant may send 30 parcels a week (Sender role).
* The same merchant may receive a parcel from a supplier using the same account (Receiver role).

### Onboarding Flows
1. **Google Onboarding Flow:**
   `Continue with Google` → Google OAuth → Select Account Type (`Individual` vs. `Business`) → If Business: Enter `Business / Shop Name` → Onboarding Transition → `Home`.
2. **Email Onboarding Flow:**
   `Continue with Email` → Provide Full Name + Email Auth → Select Account Type (`Individual` vs. `Business`) → If Business: Enter `Business / Shop Name` → Onboarding Transition → `Home`.

### Customer App Navigation Structure (Strictly 3 Tabs)
The Customer Mobile App is intentionally constrained to three primary navigation areas:
1. **Home:** Primary action button **"Send a Package"** (proceeds directly into the intercity flow) + minimal display of active/recent shipments.
2. **Shipments:** Main tracking and history hub featuring clear toggle filters for **"Parcels Sent"** and **"Parcels Received"**. Displays shipment state, Delivery Code, share button, and parcel details.
3. **Account:** Lightweight profile management (User details, Business/Shop Name, saved pickup addresses, notification preferences, support, logout).

---

## D. Cerelo Personnel Model

### Central Role of Authorized Personnel
In Cerelo V1, parcel handling is strictly controlled by **Cerelo-authorized Personnel** rather than unvetted crowdsourced drivers. Cerelo Personnel act as custody guardians and operational executors across both hubs and corridors.

```
[Sender Doorstep] ──(Personnel Pickup & Verification)──> [Origin Hub]
                                                             │
                                                     (Batch Consolidation)
                                                             │
[Receiver Doorstep] <──(Personnel Final Delivery)── [Destination Hub]
```

### Key Personnel Responsibilities Across Lifecycle
1. **First-Mile Pickup:** Attends sender location, physically inspects parcel, verifies dimensions/weight, corrects sender size selections if inaccurate, verifies payment mode, and collects payment if Sender/Split.
2. **Receiver Pre-Verification Call:** Performs a mandatory phone call to the receiver while at the sender's doorstep to verify receiver identity, delivery address, awareness of the parcel, and willingness to pay (if Receiver Pays/Split).
3. **Digital Parcel Confirmation:** Taps "Confirm Parcel" in the Personnel app to officially accept custody, generating the Parcel QR and Delivery Code.
4. **Physical Labeling:** Downloads/prints the Parcel QR label (selecting appropriate label size) and affixes it securely to the parcel.
5. **Origin Hub Processing & Batching:** Groups compatible parcels traveling on the same route into a **Batch** by scanning Parcel QRs or entering Delivery Codes, then confirms the Batch.
6. **Middle-Mile Onboarding:** Handsover consolidated Batch to middle-mile transport capacity and marks the Batch **Onboarded**.
7. **Destination Reconciliation:** Scans arriving Batch QR, scans individual Parcel QRs, reconciles physical parcels against the expected digital manifest, and flags discrepancies.
8. **Final-Mile Delivery:** Triggers "Going for Delivery", transports parcel to receiver doorstep, collects physical payment (if Receiver/Split), hands over parcel, and marks "Delivered".
9. **Sender Post-Delivery Call:** Immediately calls sender from receiver's doorstep post-handover to confirm successful delivery.

---

## E. Customer Shipment Creation Flow

When a customer taps **"Send a Package"** on the Home screen, the app bypasses any intracity/intercity selector (since V1 is intercity-only) and leads directly into the **Intercity Shipment Flow**:

```
[Home Screen] 
     │ Taps "Send a Package"
     ▼
[Pickup & Origin Form] ──────► Sender Address, Origin City (Kano or Katsina)
     │
     ▼
[Receiver & Destination Form] ► Receiver Name, Phone Number, Delivery Address, Destination City
     │
     ▼
[Parcel Details Form] ────────► Estimated Size (Small/Medium/Large), Description / Category
     │
     ▼
[Payment Responsibility] ─────► Select: [Sender Pays] | [Receiver Pays] | [Split Payment]
     │
     ▼
[Review & Submit] ────────────► Sender Taps "Request"
```

---

## F. Parcel Pickup & Confirmation Flow

### Step-by-Step Handoff Protocol
1. **Assignment & Arrival:** Cerelo assigns Personnel to collect the requested parcel. Personnel arrives at sender doorstep.
2. **Physical Size Inspection:** Personnel inspects parcel dimensions and weight. If sender selected "Small" but parcel is physically "Medium", Personnel updates the size record in the Personnel interface. Physical reality overrides sender estimate.
3. **Payment Mode Verification:** Personnel confirms selected payment mode. If **Sender Pays** or **Split Payment**, Personnel collects sender's cash/transfer payment on the spot.
4. **Mandatory Receiver Verification Call:** While physically beside sender and parcel, Personnel calls receiver phone number. Personnel confirms:
   * Receiver identity & correct destination address.
   * Receiver awareness of incoming shipment.
   * Receiver agreement to accept delivery and pay required amount (if Receiver Pays/Split).
5. **Confirm Parcel Event:** Personnel taps **"CONFIRM PARCEL"**. This formally transitions shipment status from `Requested` to `Parcel Confirmed` and registers Cerelo custody.
6. **Label Generation & Printing:** System generates **Parcel QR Code** and **Delivery Code**. Personnel selects appropriate printable label size, prints the label via portable/hub thermal printer, and affixes it to parcel.

---

## G. Parcel Identity Model

To prevent authorization vulnerabilities and maintain practical operations, Cerelo establishes a clear 4-part identity hierarchy:

| Entity Name | Format / Nature | Primary Audience | Core Purpose |
| :--- | :--- | :--- | :--- |
| **Shipment** | UUID / System Key | Internal DB & API | Top-level logical contract representing the entire door-to-door order. |
| **Parcel** | Physical Item Record | Personnel & Admin | Physical entity containing attributes (weight, verified size, category, custody history). |
| **Delivery Code** | Unique Alphanumeric Code | Customers & Personnel | Human-readable manual reference used for customer tracking, phone support, and manual lookup fallback. |
| **Parcel QR Code** | Encrypted Scannable QR | Personnel Scanning | Machine-scannable barcode label physically attached to parcel for fast hub scans and batch manifest linking. |

*Relationship:* 1 Customer Shipment ↔ 1 Physical Parcel in V1. Delivery Code and Parcel QR map directly to the same underlying parcel record.

---

## H. Batch Model

### Definition & Purpose
A **Batch** is a digital and physical consolidation model representing a group of individual parcels moving together along an intercity corridor. 

### Why Batch Replaces Smart Box in V1
Smart Box (hardware containers with embedded GPS and electronic seals) is **deferred to V2**. V1 uses digital **Batches** to achieve consolidation benefits without waiting for hardware manufacturing or IoT integration.

```
       [Parcel 1 (QR Scan)] ──┐
       [Parcel 2 (QR Scan)] ──┼──> [CREATE BATCH] ──> [CONFIRM BATCH] ──> Unique Batch QR Generated
       [Parcel 3 (Manual)]  ──┘    (Origin Hub)
```

### Batch Workflows
1. **Create Batch:** Personnel selects "Create Batch" at Origin Hub, specifying route (e.g., Kano → Katsina).
2. **Parcel Association (Manifest Building):** Personnel populates batch manifest using:
   * **Primary Method:** Scanning physical **Parcel QR Codes**.
   * **Fallback Method:** Manually typing human-readable **Delivery Codes**.
3. **Grouping Considerations:** Personnel groups parcels based on physical compatibility, weight, fragility, and volume constraints.
4. **Confirm Batch:** Personnel taps "Confirm Batch". System locks manifest relationship (`Batch 1:N Parcels`) and generates a unique **Batch QR Code**.
5. **Batch QR Printing/Display:** Batch QR is printable/viewable for middle-mile onboarding and destination scanning.

---

## I. Middle-Mile Flow

### Middle-Mile Transit Lifecycle
```
[Confirm Batch] ──► [Assign Transport] ──► [Mark Batch ONBOARDED] ──► [In Transit] ──► [Destination Receipt]
```

1. **Transport Assignment:** Consolidated Batches are assigned to available middle-mile transport capacity.
2. **Flexible Capacity Strategy:** In early Kano ↔ Katsina operations, Cerelo uses existing commercial passenger car services (such as **Kwankwasiyya** seat bookings, budgeted at ~₦7,000/seat). 
3. **Asset-Light Decoupling:** The software architecture treats transport capacity as generic and configurable (provider name, vehicle type, driver phone, capacity cost). It is **not hard-coded** to Kwankwasiyya.
4. **Mark Batch Onboarded:** Authorized Personnel executes "Mark Batch Onboarded" when transport actually departs.
5. **Cascading State Update:** Marking Batch Onboarded automatically updates all parcels in that batch to **In Transit**.

---

## J. Destination Reconciliation & Final Mile

### Destination Arrival & Reconciliation Workflow
1. **Batch Arrival:** Transport arrives at Destination City Hub. Authorized Destination Personnel scans **Batch QR Code**.
2. **Manifest Loading:** Personnel interface loads expected parcel manifest for that Batch.
3. **Item-by-Item Scan:** Personnel physically scans each arriving parcel's **Parcel QR Code**.
4. **Reconciliation Status Check:**
   * **Matched:** Physical parcel matched to manifest item.
   * **Discrepancy Triggered:** If expected parcel is missing, extra unexpected parcel arrives, or label is unreadable, system flags an Exception Record for admin review.

### Final-Mile Delivery Handoff Workflow
1. **Going for Delivery:** Destination Personnel collects reconciled parcels for delivery route and taps **"Going for Delivery"**. Customer shipment status changes to **Out for Delivery**.
2. **Doorstep Handover:** Personnel arrives at receiver address, verifies identity, and collects physical payment (if Receiver Pays or Split portion).
3. **Delivery Completion Events:**
   * Personnel taps **"Mark Delivered"** in Personnel app.
   * Receiver can optionally tap **"Confirm Delivery"** in their Customer App.
4. **Immediate Sender Telephone Call:** Post-handover, Personnel immediately calls sender from receiver doorstep to verbally confirm parcel delivery.
5. **Digital Notification:** System sends push/SMS delivery completion notification to sender.

---

## K. Tracking Model

### Status-Based Tracking Philosophy
Cerelo V1 does **NOT** provide live GPS tracking, moving map icons, or courier phone location polling. Tracking is strictly **status-based**, driven by verified physical handoff events.

### Recommended Customer Status Taxonomy

```
[Requested] ──► [Parcel Confirmed] ──► [At Origin Hub] ──► [In Transit] ──► [Arrived Destination] ──► [Out for Delivery] ──► [Delivered]
```

1. **Requested:** Customer submitted shipment request; pickup pending.
2. **Parcel Confirmed:** Personnel physically verified parcel size, called receiver, collected pickup payment (if applicable), and accepted parcel into custody.
3. **At Origin Hub:** Parcel arrived at origin hub and is being consolidated into a Batch.
4. **In Transit:** Batch has been marked "Onboarded" and is traveling between cities.
5. **Arrived Destination:** Destination hub scanned Batch QR and reconciled parcel.
6. **Out for Delivery:** Destination Personnel marked "Going for Delivery" and is en route to receiver.
7. **Delivered:** Parcel physically handed to receiver; payment verified.

> **Principle of No Fake Certainty:** Status updates must reflect actual physical events performed by Personnel. Timers or estimated duration algorithms must never automatically trigger status transitions.

---

## L. Payment Model

### Payment Responsibility Modes
Before submitting a request, sender selects one of three payment responsibilities:
1. **Sender Pays (100%):** Sender pays full delivery fee to Personnel at pickup.
2. **Receiver Pays (100%):** Receiver pays full delivery fee to Personnel at destination doorstep.
3. **Split Payment:** Sender pays agreed portion at pickup; receiver pays remaining portion at delivery.

### Physical Payment Collection Protocol
* **No Digital Wallet / Escrow in V1:** Payment collection is physical cash or instant mobile transfer collected directly by Cerelo Personnel during physical interaction.
* **Recording:** Personnel records payment collection event in their app (Amount Collected, Collector ID, Timestamp, Payment Method).

### Unresolved Payment Areas (Requiring Requirements Freeze)
* Exact ratio calculation for Split Payment (Fixed 50/50 vs custom split).
* Official protocol for receiver cash refusal at doorstep (handling return fees / hub holding).

---

## M. Customer Sharing & Receiver Access

### Delivery Code & Share Link Mechanics
Inside **Shipments → Specific Shipment**, sender can tap **"Share Shipment"** or **"Copy Link"**.

```
Sender taps "Share Link" ──► Generates deep-link URL ──► Sent via WhatsApp/SMS to Receiver
                                                                 │
      ┌──────────────────────────────────────────────────────────┴──────────────────────────────────────────────────────────┐
      ▼                                                                                                                     ▼
[App Installed]                                                                                                   [App NOT Installed]
Link opens Cerelo App directly to "Parcels Received" detail page                                                   Link opens mobile web landing page / App Store redirect
```

### Privacy & Data Isolation Boundaries
Shared links grant tracking access **only** to that specific shipment. The receiver must **never** be able to view:
* Sender's full profile details or saved personal addresses.
* Sender's unrelated shipments or order history.
* Internal Cerelo Personnel operational notes, driver names, or batch metadata.
* Unrelated customer data.

---

## N. Initial Launch Model

### Operating Environment & Strategy
* **Launch Corridor:** Kano ↔ Katsina (Bi-directional).
* **Key Commercial Hub:** Kantin Kwari Market, Kano (focusing on textiles, fashion, and social-commerce sellers).
* **Founder-Operated Pilot:** Founders will personally execute operations (pickup, batching, middle-mile coordination, delivery) and rotate between Kano and Katsina every ~2 weeks to gain ground-level insights.
* **Initial Fleet Resources:** 1 motorcycle available in Katsina, 1 motorcycle available in Kano for first/final mile.
* **Software Architecture Governance:** Despite founders performing operational roles initially, the software **must enforce role-based access control (Admin, Personnel, Customer)** without hard-coding founder accounts.

---

## O. Business Metrics Cerelo Must Capture

To validate business viability during the pilot, V1 software must log operational events allowing extraction of these core metrics:

```
┌───────────────────┬──────────────────────────────────────────────────────────────────────────────┐
│ Metric Domain     │ Specific Data Points Captured                                                │
├───────────────────┼──────────────────────────────────────────────────────────────────────────────┤
│ 1. Demand         │ Total Shipment Requests, Request-to-Confirmed Conversion Rate, Repeat Senders│
│ 2. Volume         │ Daily Parcels, Parcels per Direction (Kano→Katsina vs Katsina→Kano), Batch Size│
│ 3. Revenue        │ Revenue per Parcel, Revenue per Batch, Payment Mode Mix (Sender/Receiver/Split)│
│ 4. Direct Costs   │ First-Mile Pickup Cost, Middle-Mile Seat/Transit Cost, Final-Mile Delivery Cost│
│ 5. Reliability    │ Delivery Success Rate, Batch Reconciliation Mismatch Rate, Lost/Damaged Rate │
│ 6. Velocity (SLA) │ Time to Pickup, Time to Batch, Transit Duration, Time to Final Handover       │
└───────────────────┴──────────────────────────────────────────────────────────────────────────────┘
```

---

## P. Locked Decisions vs Assumptions

### LOCKED V1 DECISIONS (DO NOT CHANGE)
1. **Service Focus:** Intercity door-to-door parcel delivery ONLY. Intracity is strictly excluded.
2. **Launch Corridor:** Kano ↔ Katsina (bi-directional).
3. **No Marketplace Couriers:** Independent rider bidding, ₦1,000 fare suggestions, and courier marketplaces are removed.
4. **Single Customer Account Model:** Unified account for sending/receiving; role is shipment-specific.
5. **App Navigation:** Exactly 3 primary tabs: Home, Shipments, Account.
6. **Direct Order Flow:** "Send a Package" leads directly into intercity form.
7. **Onboarding:** Google and Email authentication with Individual vs Business selection.
8. **Payment Responsibility:** Sender Pays, Receiver Pays, Split Payment supported.
9. **Physical Payment:** Cash/transfer collected by Personnel at pickup/delivery. No stored-value wallet.
10. **Personnel Control:** Dedicated Cerelo Personnel handle pickup, verification, batching, reconciliation, and delivery.
11. **Pickup Verification:** Personnel physically verifies and corrects parcel size before confirmation.
12. **Receiver Call:** Personnel calls receiver from sender doorstep prior to parcel confirmation.
13. **Confirm Parcel Event:** Formal digital custody acceptance generating Parcel QR and Delivery Code.
14. **Printable QR Labels:** Selectable label sizing for thermal/inkjet printing and physical attachment.
15. **Digital Batch Model:** Origin hub parcel consolidation via QR scanning or Delivery Code fallback. Batch replaces Smart Box in V1.
16. **Batch QR Code:** Unique Batch QR generation for middle-mile onboarding and destination scanning.
17. **Onboarding Trigger:** Marking Batch Onboarded updates associated parcels to "In Transit".
18. **Status Tracking Only:** No live GPS tracking, polylines, or real-time map icons in V1.
19. **Destination Reconciliation:** Mandatory scanning of Batch QR and individual Parcel QRs at destination hub.
20. **Final-Mile Trigger:** "Going for Delivery" transitions status to "Out for Delivery".
21. **Delivery Completion:** Personnel marks "Delivered", Receiver optionally confirms, Personnel calls sender from doorstep.
22. **Deferred Scope:** Smart Box hardware and IoT seals are deferred to V2.

### CURRENT ASSUMPTIONS / HYPOTHESES (CONFIGURABLE PARAMETERS)
1. **Average Revenue per Parcel:** ₦3,000 hypothesis.
2. **Middle-Mile Capacity Cost:** ₦7,000 per passenger car seat/capacity hypothesis.
3. **Target Batch Size:** ~10 parcels per consolidated Batch hypothesis.
4. **Middle-Mile Transport Provider:** Kwankwasiyya passenger car service assumption.
5. **Parcel Size Tiers:** Specific weight/dimension bounds (e.g., Small, Medium, Large).
6. **Delivery Timeframe SLA:** Same-day vs Next-day targets.
7. **Delivery Code & Batch ID Formats:** Specific alphanumeric string structure.

---

## Q. Contradictions / Ambiguities / Unresolved Decisions

| # | Unresolved Issue | Why It Matters | Recommended Direction | Resolution Timeline |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **Personnel Interface Technology** | Determines offline capabilities, camera scanning performance, and deployment complexity. | Build mobile-first PWA or cross-platform web app optimized for mobile viewports and camera QR scanning. | Safe for Technical Architecture |
| **2** | **Split Payment Ratio Logic** | Senders and receivers need unambiguous payment figures before confirming request. | Default to 50/50 split in V1 with option for sender to specify custom fixed split. | Resolve in Prompt 2 (Requirements Freeze) |
| **3** | **Failed Delivery / Refusal Protocol** | If receiver refuses payment at doorstep, custody and financial responsibility must be defined. | Personnel marks "Delivery Attempt Failed - Payment Refused". Parcel returns to destination hub; sender notified for return fee. | Resolve in Prompt 2 (Requirements Freeze) |
| **4** | **Delivery Confirmation State Semantics** | Clarify if Personnel "Delivered" mark closes shipment or requires Receiver app confirmation. | Personnel "Delivered" mark completes operational delivery and releases payout/closure; Receiver confirmation acts as optional trust endorsement. | Resolve in Prompt 2 / State Architecture |
| **5** | **Parcel Size Category Definitions** | Personnel need objective criteria to correct sender size selections. | Establish weight/volume tiers: Small (<=3kg, fits envelope/shoe box), Medium (<=10kg, carton), Large (<=25kg, sack). | Resolve in Prompt 2 (Requirements Freeze) |

---

## R. V1 Product Risks

### 1. Middle-Mile Transport Reliability Risk — [RANK: BLOCKER]
* **Risk:** Complete reliance on third-party commercial cars (Kwankwasiyya) without formal SLAs means transport drivers may reject parcel cargo or delay departure.
* **Mitigation:** Maintain relationships with multiple transport drivers/parks in Kano and Katsina; keep middle-mile provider model configurable in software.

### 2. Receiver Payment Refusal at Doorstep — [RANK: HIGH]
* **Risk:** Personnel delivers parcel under "Receiver Pays", but receiver refuses to pay or lacks cash/transfer capability, stranding Personnel.
* **Mitigation:** Strict enforcement of pre-pickup receiver verification call by Personnel. If receiver expresses hesitation during pickup call, parcel is not confirmed.

### 3. Parcel Damage / Loss During Unenclosed Transit — [RANK: HIGH]
* **Risk:** Without V2 Smart Boxes, parcels in car trunks are vulnerable to damage or informal swapping.
* **Mitigation:** Strict origin batch manifest checks, fragile parcel grouping rules, and mandatory destination QR reconciliation.

### 4. Operational Process Non-Compliance — [RANK: HIGH]
* **Risk:** Personnel rush operations and skip the mandatory receiver phone call or parcel size verification step.
* **Mitigation:** Software workflow gating—Personnel app forces phone call log confirmation and size confirmation step before enabling "Confirm Parcel" button.

### 5. Intermittent Cellular Connectivity in Transit — [RANK: MEDIUM]
* **Risk:** Poor network coverage along Kano-Katsina highway causes offline QR scan failures.
* **Mitigation:** Implement offline-first local queueing in Personnel app for QR scanning and reconciliation actions, syncing once connected.

### 6. Unauthorized Shipment Detail Access via Shared Links — [RANK: MEDIUM]
* **Risk:** Unauthenticated users guessing or receiving shared links access customer address or privacy data.
* **Mitigation:** Scope shared links strictly to anonymous tracking view (status timeline and parcel description only); scrub sender address details.

---

## S. Product Principles

1. **Simplicity Over Feature Density:** Customers should never manage internal logistics (motor parks, drivers, batching). If Cerelo can solve it internally, hide the complexity.
2. **Transparency Without Noise:** Customers receive clear status updates for meaningful milestones. Avoid spamming notifications for minor operational scans.
3. **Physical Reality Rules Digital State:** A digital state transition must represent a verified physical event. "No Fake Certainty" (no live map icons without real GPS; no automatic status timers).
4. **Trust Through Human Touchpoints:** Retain high-trust human mechanisms in V1 (doorstep pre-verification call, post-delivery call) to complement digital tracking.
5. **Strict Scope Discipline:** Validate Kano ↔ Katsina intercity logistics before expanding to intracity, Smart Boxes, or new cities.
6. **Mobile-First Reality:** Software must operate seamlessly on modest Android devices with variable network quality.
7. **Auditable Custody:** Every handoff (Pickup → Hub → Batch → Transport → Destination Hub → Delivery) must record actor, timestamp, and location.

---

## T. Questions Requiring Founder Confirmation

### MUST ANSWER BEFORE PROMPT 2 (REQUIREMENTS FREEZE)
1. **Parcel Size Category Definitions:** What are the exact weight and dimension boundaries for Small, Medium, and Large parcel sizes in V1?
2. **Split Payment Rule:** Is Split Payment strictly a fixed 50/50 split, or can the sender specify custom split amounts (e.g. Sender 70%, Receiver 30%)?
3. **Doorstep Refusal Policy:** If a receiver refuses to pay for a "Receiver Pays" parcel at delivery, what is the mandatory operational protocol (Return to Destination Hub vs. Return to Sender in Kano)?
4. **Primary Delivery Completion Trigger:** Does Personnel marking "Delivered" immediately complete the shipment state, or is Receiver app confirmation mandatory?

### CAN BE DEFERRED TO TECHNICAL ARCHITECTURE / IMPLEMENTATION
1. **Personnel App Tech Stack:** Preferred technology framework for Personnel UI (PWA vs Native Android app)?
2. **Hub Printing Hardware:** Thermal barcode printer specifications and connectivity (Bluetooth vs USB) deployed at Kano/Katsina hubs?
3. **Customer Dynamic Pricing Formula:** Base delivery pricing structure per size category for Kano ↔ Katsina corridor?
