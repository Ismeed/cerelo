# CERELO V1 — RELIABILITY & FAULT TOLERANCE ARCHITECTURE

> **Defines how Cerelo V1 maintains strict physical-state truth, financial consistency, and communication reliability in real-world Nigerian network conditions.**

---

## 1. TRANSACTIONAL OUTBOX ARCHITECTURE

To ensure that notification failures or external provider timeouts never roll back authoritative business data:
1. Every domain mutation (e.g., `confirm_parcel_pickup`, `onboard_batch`, `mark_delivered`) commits business tables atomically in PostgreSQL.
2. In the same database transaction, a record is inserted into `notification_outbox`.
3. Background workers claim batches from `notification_outbox` with exponential backoff retry.
4. **Guaranteed Invariant:** Even if mobile push services or network gateways fail completely, physical logistics truth and financial ledgers remain 100% accurate.

---

## 2. IDEMPOTENCY & CONCURRENCY MATRIX

| Critical Mutation | Idempotency Key / Guard | Concurrent Action Protection |
|:---|:---|:---|
| `create_shipment_request` | `idempotency_key` parameter | Returns existing shipment if duplicate key received |
| `record_physical_payment` | Unique `payment_collections.idempotency_key` | Disallows double cash recording on retries |
| `confirm_parcel_pickup` | `parcels.current_parcel_state = 'UNCONFIRMED'` check | Only one personnel can accept custody |
| `add_parcel_to_batch` | Partial unique index on `batch_memberships(parcel_id) WHERE is_active = TRUE` | Parcel can belong to only one active batch |
| `confirm_batch` | `batches.current_batch_state = 'DRAFT'` check | Manifest freezes; duplicate calls return existing QR |
| `onboard_batch` | `batches.current_batch_state = 'CONFIRMED'` check | Intercity departure executes exactly once |
| `mark_delivered` | `shipments.current_status = 'OUT_FOR_DELIVERY'` check | Duplicate handovers safely return existing delivered state |

---

## 3. OFFLINE CAPABILITY & DISCONNECTION HANDLING

- **Read Operations:** Cached shipment list and task summaries allow viewing previous states without network.
- **Write Mutations:** State-changing actions require server confirmation. Buttons display "Connecting / Verifying" rather than showing false optimistic green success before server response.
- **Recovery on Restart:** If the Personnel App terminates mid-pickup or mid-delivery, reopening the app queries the server and restores the authoritative in-progress task.
