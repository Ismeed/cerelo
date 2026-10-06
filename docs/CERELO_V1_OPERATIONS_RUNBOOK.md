# CERELO V1 — FIELD OPERATIONS RUNBOOK

> **Authoritative operational procedures for Cerelo field staff and operations management across the Kano ↔ Katsina corridor.**

---

## 1. PHYSICAL PICKUP & ORIGIN SENDER EXCEPTIONS

### Scenario 1.1: Sender Unavailable / Address Unreachable
- **Physical Reality:** Personnel arrives at pickup location in Kano, but Sender does not answer phone or is absent.
- **Field Action:** Attempt 2 phone calls 5 minutes apart. If still unreachable, record pickup attempt as `SENDER_UNAVAILABLE`.
- **System Action:** In Personnel App, tap "Report Issue" $\rightarrow$ select `SENDER_UNAVAILABLE`.
- **Strict Rule:** **DO NOT** confirm the parcel or accept custody. Shipment remains in `REQUESTED` state.

### Scenario 1.2: Sender Declared Size Mismatch
- **Physical Reality:** Sender booked "Small" but physically presents a large 15kg textile bundle.
- **Field Action:** Explain size correction to Sender (from ₦2,000 to ₦6,000 Large).
- **System Action:** In Personnel App, select "Correct Parcel Size" $\rightarrow$ select `Large`.
- **If Sender Agrees:** Collect corrected fee $\rightarrow$ tap "Confirm Parcel".
- **If Sender Rejects:** Tap "Cancel Pickup" $\rightarrow$ do not take custody.

### Scenario 1.3: Network Timeout during Cash Collection
- **Physical Reality:** Personnel collects ₦3,500 cash from Sender, taps "Confirm Cash Collected", but mobile screen spins or shows network error.
- **Field Action:** **DO NOT** ask Sender for money again.
- **System Action:** Reopen the pickup task. The system checks server idempotency. If already recorded, state shows `COLLECTED`. Tap "Confirm Parcel" to proceed.

---

## 2. ORIGIN SORTING HUB & BATCH CONSOLIDATION

### Scenario 2.1: Damaged Parcel QR Label
- **Physical Reality:** Origin hub scanner fails to read a scuffed QR code.
- **Field Action:** Tap "Manual Delivery Code" on the scanner screen.
- **System Action:** Enter `CRL-XXXX-XXXX` from the physical label. Proceed with hub receipt. Reprint a fresh label if necessary.

### Scenario 2.2: Missing Expected Parcel in Confirmed Batch
- **Physical Reality:** A batch manifest has 8 parcels locked, but only 7 are physically loaded onto the intercity vehicle.
- **Field Action:** If batch is in `DRAFT`, remove the 8th parcel from the manifest before confirmation.
- **If Batch is already `CONFIRMED`:** Flag the parcel as `MISSING` during destination reconciliation. **DO NOT** onboard the batch with unrecorded missing physical parcels.

---

## 3. MIDDLE-MILE TRANSIT & VEHICLE DEPARTURE

### Scenario 3.1: Commercial Transit Delay
- **Physical Reality:** Minivan transit is delayed at Kwanar Dawaki due to tire replacement.
- **Field Action:** Middle-mile personnel informs destination hub manager.
- **System Action:** Batch remains in `ONBOARDED` / `IN_TRANSIT` state.
- **Strict Rule:** Destination arrival is **NEVER** automatically marked by a timer. It requires physical arrival at Katsina hub.

---

## 4. DESTINATION RECONCILIATION

### Scenario 4.1: Unexpected Parcel Present in Container
- **Physical Reality:** An unmanifested parcel is physically found inside the Katsina arrival bundle.
- **Field Action:** Scan the Parcel QR. Tap "Record Unexpected Parcel Finding".
- **System Action:** Server records discrepancy in `batch_reconciliation_records` without mutating the frozen departure manifest.

---

## 5. FINAL-MILE DOORSTEP DELIVERY & SENDER COMPLETION CALL

### Scenario 5.1: Receiver Refuses Payment (Receiver Pays)
- **Physical Reality:** Recipient at 14 IBB Way Katsina refuses to pay the ₦3,500 delivery fee.
- **Field Action:** **DO NOT** hand over the package.
- **System Action:** In Personnel App, tap "Report Issue" $\rightarrow$ select `PAYMENT_REFUSED`.
- **Custody:** Return package to Katsina Central Hub for operations follow-up.

### Scenario 5.2: Mandatory Doorstep Sender Completion Call (LOCKED SOP)
- **Physical Reality:** Parcel physically handed over to Receiver. Personnel taps "Confirm Handover & Mark Delivered".
- **Field Action:** **Before leaving Receiver's doorstep**, tap "Call Sender" in the app. Inform the Sender: *"Salamu alaikum, this is Cerelo. Your parcel has just been handed to Hajiya Fatima in Katsina."*
- **System Action:** Select `REACHED_AND_CONFIRMED` or `NO_ANSWER` $\rightarrow$ tap "Record Call Outcome".
