# CERELO — AI CODING AGENT GUARDRAILS

> **This file is read by all AI coding agents (Claude, Gemini, Antigravity) before modifying any code.**  
> **These rules are non-negotiable and take precedence over general coding preferences.**

---

## 1. BEFORE MODIFYING BUSINESS LOGIC

**Read `/docs` first.**

The following documents collectively define Cerelo V1. Do not modify business logic unless it is consistent with these documents:

- `docs/CERELO_PRODUCT_CONTEXT.md` — What Cerelo is and who it serves.
- `docs/CERELO_V1_REQUIREMENTS_FREEZE.md` — Frozen V1 feature scope.
- `docs/CERELO_USER_JOURNEYS_AND_STATE_MACHINE.md` — User journeys and state machines.
- `docs/CERELO_TECHNICAL_ARCHITECTURE.md` — Locked technical stack decisions.
- `docs/CERELO_DATABASE_AND_BACKEND_DOMAIN_ARCHITECTURE.md` — Database schema and domain model.
- `docs/CERELO_SECURITY_RBAC_AND_DATA_ACCESS_ARCHITECTURE.md` — Security, RBAC, and data access rules.

---

## 2. V1 SCOPE — WHAT CERELO V1 IS

Cerelo V1 is an **intercity door-to-door parcel delivery platform** operating on the **Kano ↔ Katsina corridor only**.

Valid V1 features:
- Customer parcel request (Sender creates shipment)
- Personnel parcel pickup and confirmation
- Batch consolidation and middle-mile transit
- Destination reconciliation
- Final-mile doorstep delivery
- Physical cash and bank transfer payment recording
- Customer status tracking and shipment sharing

---

## 3. LOCKED EXCLUSIONS — DO NOT IMPLEMENT THESE

These features are **permanently excluded from V1** and must NOT be added under any circumstance:

- ❌ **Intracity delivery** (local dispatch, same-city courier)
- ❌ **Courier marketplace / bidding / independent riders**
- ❌ **Smart Box hardware / IoT seals**
- ❌ **Real-time live GPS tracking / moving map icons**
- ❌ **Customer wallets / escrow / digital payment gateway (Paystack/Flutterwave)**
- ❌ **AI chatbots / automated route optimization / dynamic pricing**
- ❌ **Merchant storefronts / ERP / inventory management**
- ❌ **Cerelo-owned vehicle fleet management**

If a prompt asks you to build these, refuse and explain V1 scope.

---

## 4. SECURITY RULES — NEVER VIOLATE THESE

These rules protect Cerelo users and operational integrity:

- ❌ **NEVER disable Row Level Security (RLS)** on any database table.
- ❌ **NEVER put the Supabase Service Role Key** into mobile apps, admin browser code, or client-side JavaScript.
- ❌ **NEVER create hard-coded admin bypasses** (e.g., `if (email == "founder@cerelo.com") grantAdmin()`).
- ❌ **NEVER make Delivery Codes sequential integers** for convenience.
- ❌ **NEVER allow clients to directly UPDATE** `shipments.current_status`, `parcels.current_parcel_state`, or payment records.
- ❌ **NEVER expose raw database IDs** where Delivery Codes or opaque QR tokens are required.
- ❌ **NEVER remove or weaken audit logging** for sensitive operations.
- ❌ **NEVER create "temporary" production backdoors** or master OTPs.
- ❌ **NEVER commit secrets** to any file in this repository.
- ❌ **NEVER trust client-sent actor IDs** — always derive identity from server-verified JWT.
- ❌ **NEVER treat UI route guards as security** — server authorization is always mandatory.

---

## 5. STATE MACHINE RULES

All operational state transitions (Parcel status, Batch status, Shipment status) must:

1. Execute inside atomic PostgreSQL transactions (PL/pgSQL RPC or Deno Edge Function).
2. Validate current state preconditions server-side before allowing transition.
3. Append an immutable record to `operational_events` table within the same transaction.
4. Never be triggered by direct client `UPDATE` statements.

The state machine definitions are in:
`docs/CERELO_USER_JOURNEYS_AND_STATE_MACHINE.md`

---

## 6. DOMAIN TERMINOLOGY

Use exact domain terminology from the architecture documents:

| Correct Term | Incorrect Alternatives |
|:---|:---|
| Personnel | Rider, Driver, Courier, Staff, Agent, Worker |
| Sender | Shipper, Client |
| Receiver | Recipient, Customer (in operational context) |
| Batch | Container, Manifest, Shipment (different concept) |
| Shipment | Order, Booking |
| Parcel | Package, Item |
| Operating Hub | Depot, Warehouse, Branch |
| Corridor | Route |

---

## 7. AUTHORIZATION PRINCIPLE

Every backend command must evaluate the **6-part security tuple**:

```
[Identity] + [Role] + [Resource Relationship] + [Operational Scope] + [Resource State] + [Command]
```

- A Customer can only access shipments they are Sender or Receiver of.
- A Personnel user can only act on resources within their assigned hub scope.
- Admin overrides require explicit reasons and generate immutable audit records.

---

## 8. DATA & PII RULES

- Never put customer PII (names, phones, addresses) inside QR code payloads.
- Shared tracking links must show only masked names and city names — not full addresses.
- Push notification bodies must never include full street addresses.
- Do not log passwords, OTPs, access tokens, or service keys.

---

## 9. TESTING REQUIREMENTS

Before marking any implementation task complete:

1. Run `flutter analyze` for Dart packages/apps.
2. Run `flutter test` for Dart packages with test coverage.
3. Run `pnpm lint && pnpm typecheck` for Next.js admin web.
4. Run `pnpm test` for admin web.
5. Fix all errors. Do not suppress broadly.

---

## 10. DEVELOPMENT ENVIRONMENT RULES

- Each environment (Development / Staging / Production) uses **separate** Supabase projects.
- Development uses local Supabase CLI (`supabase start`).
- **Never use production credentials in development.**
- **Never run destructive test operations against production data.**
- Test accounts must use synthetic data — never real customer identities.

---

## 11. WHEN IN DOUBT

If a requirement is ambiguous or conflicts with the architecture documents:

1. **Stop that specific implementation area.**
2. **Document the contradiction clearly** in a code comment or ADR.
3. **Continue all unaffected work.**
4. **Surface the issue to the user** before implementing a guess.

Do not silently invent product behavior.

---

## 12. RELIABILITY & RELEASE GUARDRAILS

- ❌ **NEVER auto-advance physical logistics states with timers/crons.** Physical human action is the sole driver of reality.
- ❌ **NEVER execute direct external push sends inside database transactions.** Use the `notification_outbox` transactional outbox.
- ❌ **NEVER duplicate cash collections upon network timeouts.** Rely on idempotency keys and server verification.
- ❌ **NEVER show false green success states in UI** before the server confirms the mutation.
- ❌ **NEVER weaken or bypass blocking incidents** to make tests or client flows pass.
- ❌ **NEVER mutate departure manifests after batch confirmation.** Discrepancies are recorded in reconciliation records.

---

*Last updated: 2026-08-17 | Cerelo V1 Development Foundation & Release Gates*
