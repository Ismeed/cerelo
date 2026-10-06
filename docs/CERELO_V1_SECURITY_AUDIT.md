# CERELO V1 — SECURITY & RBAC AUDIT REPORT

> **Comprehensive assessment of authentication boundaries, authorization enforcement, Row Level Security, and privacy protections.**

---

## 1. 6-PART SECURITY TUPLE ENFORCEMENT

Every sensitive operational command evaluates:
```
[Identity] + [Role] + [Resource Relationship] + [Operational Scope] + [Resource State] + [Command]
```

### Verified Protections:
1. **Zero Client Trust:** All state transitions and custody changes execute exclusively inside PostgreSQL `SECURITY DEFINER` RPCs using `auth.uid()`.
2. **Actor Role Immutability:** Customer cannot elevate themselves to Personnel or Admin; roles are derived strictly from internal server tables (`personnel`, `admins`).
3. **Operational Scope:** Field personnel assigned to Kano Central Hub cannot perform Katsina destination arrivals or reconciliation unless explicitly authorized.
4. **Delivered State Protection:** Completed shipments cannot be casually reverted to in-transit or draft states; administrative corrections are restricted to audited metadata adjustments.

---

## 2. IDOR / BOLA PROTECTION

- **Shipments:** Customers can only query shipments where they are the authenticated `sender_customer_id` or linked `receiver_customer_id`.
- **Public Share Links:** Public shared tracking links resolve through opaque tokens, exposing only city-level progress and masked recipient names without full street addresses or phone numbers.
- **Delivery Codes:** `CRL-XXXX-XXXX` reference codes are non-sequential, rate-limited against brute-force lookups, and do not authorize full resource access on their own.

---

## 3. AUDIT TRAILS & FINANCIAL INTEGRITY

- **Payment Ledger:** Physical cash and transfer collections require explicit personnel attribution, idempotency keys, and never overwrite historical collection records.
- **Administrative Overrides:** Any correction to recipient details, staff suspensions, corridor toggles, or pricing rules generates an immutable row in `admin_audit_logs` with before/after snapshots and mandatory reasons.
