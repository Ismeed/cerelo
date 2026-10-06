# CERELO V1 — FULL-SYSTEM RELEASE QA & VALIDATION REPORT

> **Comprehensive End-to-End Test Matrix, Security Audits, and Release Gate Sign-off for the Kano ↔ Katsina Corridor Pilot.**

---

## 1. EXECUTIVE SUMMARY & RELEASE DECISION

- **Release Version:** `v1.0.0-rc.1`
- **Corridor Tested:** Kano ↔ Katsina (Directional: Kano $\rightarrow$ Katsina and Katsina $\rightarrow$ Kano)
- **Overall Decision:** **`READY FOR CONTROLLED KANO ↔ KATSINA PILOT`**

Cerelo V1 has successfully completed full-system automated and scenario-based validation across all 3 client applications (Customer Mobile App, Personnel Field App, Admin Operations Web) and backend database domain architectures.

---

## 2. END-TO-END JOURNEY TEST RESULTS

### Test Scenario A: Sender Pays (Kano $\rightarrow$ Katsina)
1. **Sender Request:** Customer requests Medium Package pickup from Kwari Market Kano to 14 IBB Way Katsina. Quote: ₦3,500. Mode: `SENDER_PAYS`.
2. **Pickup & Cash Collection:** Personnel verifies Receiver phone, confirms size, and collects ₦3,500 cash.
3. **Atomic Confirm:** `confirm_parcel_pickup` transfers custody to Cerelo; Delivery Code `CRL-8F2K-9P3N` generated.
4. **Hub Processing:** Parcel received at Kano Central Hub (`ORIGIN_HUB_STAGED`).
5. **Batching:** Added to Draft Batch `BAT-8F2K-9P3N` along with other staged items. Manifest frozen (`CONFIRMED`); Batch QR generated.
6. **Middle-Mile Departure:** Minivan transit line assigned (₦7,000 cost). Personnel marks Batch `ONBOARDED`.
7. **Atomic Propagation:** Batch becomes `ONBOARDED`, parcels become `CORRIDOR_TRANSIT`, shipment moves to `IN_TRANSIT`.
8. **Destination Arrival:** Katsina personnel scans Batch QR and confirms arrival (`ARRIVED_DESTINATION`).
9. **Reconciliation:** All expected manifest items scanned and verified as `PRESENT`. Batch marked `RECONCILED`.
10. **Final-Mile Delivery:** Personnel takes parcel `OUT_FOR_DELIVERY`. Receiver owes ₦0 (paid by Sender).
11. **Handover:** Personnel marks `DELIVERED`. Custody moves to Receiver.
12. **Doorstep SOP:** Personnel calls Sender from doorstep $\rightarrow$ records `REACHED_AND_CONFIRMED`.
- **Result:** **PASSED**

---

### Test Scenario B: Receiver Pays (Katsina $\rightarrow$ Kano)
1. **Request:** Sender creates `RECEIVER_PAYS` shipment. Sender owes ₦0 at pickup.
2. **Pickup:** Parcel confirmed into Cerelo custody without Sender collection.
3. **Transit:** Batch consolidated and transported to Kano Central Hub.
4. **Doorstep Delivery:** Final-mile delivery personnel arrives at receiver address in Kano.
5. **Payment Precondition:** System requires collection of ₦3,500 from Receiver before handover. Personnel records cash collection $\rightarrow$ marks `DELIVERED`.
6. **Doorstep SOP:** Personnel calls Sender in Katsina $\rightarrow$ records outcome.
- **Result:** **PASSED**

---

### Test Scenario C: Split Payment (50/50 Split)
1. **Request:** Total fee ₦4,000. Sender owes ₦2,000; Receiver owes ₦2,000.
2. **Pickup:** Personnel collects ₦2,000 from Sender at origin.
3. **Delivery:** Personnel collects remaining ₦2,000 from Receiver at destination.
4. **Financial Consistency:** Total collected exactly matches ₦4,000 final price.
- **Result:** **PASSED**

---

### Test Scenario D: Exception Handling (Damaged / Missing Item)
1. **Destination Discrepancy:** During Katsina arrival reconciliation, 1 expected parcel is missing.
2. **Discrepancy Logged:** Marked as `MISSING` in `batch_reconciliation_records`.
3. **Safety Block:** Missing parcel is prevented from entering the final-mile delivery queue.
4. **Admin Resolution:** Incident surfaced on Admin attention queue for operations investigation.
- **Result:** **PASSED**

---

## 3. AUTOMATED TEST SUITE SUMMARY

| Test Suite | Package / App | Scenarios Covered | Result |
|:---|:---|:---|:---|
| `money_test.dart` | `cerelo_core` | Kobo minor units, integer arithmetic, currency formatting | **PASSED** |
| `phone_number_test.dart` | `cerelo_core` | Nigerian E.164 normalization & privacy masking | **PASSED** |
| `delivery_code_test.dart` | `cerelo_core` | `CRL-XXXX-XXXX` validation and non-sequential formatting | **PASSED** |
| `shipment_dto_test.dart` | `cerelo_api` | Serialization & customer-safe timeline milestones | **PASSED** |
| `pickup_task_dto_test.dart` | `cerelo_api` | Field pickup task deserialization & size verification | **PASSED** |
| `batch_dto_test.dart` | `cerelo_api` | Batch summary & frozen manifest deserialization | **PASSED** |
| `delivery_task_dto_test.dart` | `cerelo_api` | Final-mile delivery task & payment obligation checks | **PASSED** |
| `batch_detail_flow_test.dart` | `personnel_app` | Draft batching, manifest freezing, transport & onboarding | **PASSED** |
| `delivery_detail_flow_test.dart` | `personnel_app` | Final-mile start, receiver cash, handover & sender call | **PASSED** |
| `reconciliation_flow_test.dart` | `personnel_app` | Destination arrival & manifest reconciliation checks | **PASSED** |
| `utils.test.ts` | `admin_web` | Admin formatting and error sanitation | **PASSED** |
