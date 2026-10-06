# ADR 0001 — Monorepo Strategy

**Status:** Accepted  
**Date:** 2026-08-17  
**Deciders:** Cerelo Founding Team

---

## Context

Cerelo V1 requires three distinct client surfaces that share domain types, validation logic, and design tokens:

1. **Customer App** (Flutter/Android+iOS)
2. **Personnel App** (Flutter/Android+iOS)
3. **Admin Operations Panel** (Next.js/Web)

Additionally, the backend (Supabase Deno Edge Functions) shares error codes and data structures with all three clients.

We needed a repository strategy that:
- Maximizes code reuse (domain types, enums, validation)
- Maintains clear application boundaries
- Supports a 1–3 developer team without excessive tooling overhead
- Keeps all architectural governance (AGENTS.md, docs/) centrally accessible

---

## Decision

Adopt a **monorepo** at `github.com/cerelo/cerelo` with:

| Tool | Scope | Purpose |
|:---|:---|:---|
| **Melos** | Dart/Flutter | Workspace management for `apps/customer_app`, `apps/personnel_app`, `packages/cerelo_core`, `packages/cerelo_api`, `packages/cerelo_ui` |
| **pnpm Workspaces** | JavaScript | Workspace management for `apps/admin_web` |
| **Supabase directory** | Backend | Migrations and Edge Functions at repository root |

---

## Package Architecture

```
packages/cerelo_core   ← Domain types, enums, Money, PhoneNumber, DeliveryCode
packages/cerelo_api    ← Supabase client wrapper, AuthService, DTOs
packages/cerelo_ui     ← Design system, CereloTheme, shared widgets
```

Both Flutter apps depend on all three packages. The admin web has its own TypeScript equivalents for domain types.

---

## Consequences

**Positive:**
- Domain types (ShipmentStatus, ParcelSize, PaymentMode, etc.) defined once in `cerelo_core` and shared across both mobile apps — no drift risk
- Design system (`cerelo_ui`) maintained once, applied consistently across Customer and Personnel surfaces
- All AI agent guardrails, architecture documents, and AGENTS.md in one repository
- Single CI pipeline configuration covers the full system
- `melos run analyze` and `melos run test` check all packages in one command

**Negative:**
- Developers working only on admin_web must still clone the full repository (including Flutter dependencies)
- Requires both Melos and pnpm as monorepo tools (one per language ecosystem)
- Initial setup is slightly more involved than a single-package project

---

## Alternatives Considered

| Alternative | Reason Rejected |
|:---|:---|
| Separate repositories per app | Domain type duplication and drift risk between Customer App and Personnel App |
| Single pubspec.yaml with all code | No clear package boundaries; mixes UI, API, and domain layers |
| nx monorepo (JavaScript-first) | Does not support Dart/Flutter natively |
