# scripts/lib — Cerelo Test Isolation & Safe DB Client Library

This directory contains shared tooling for approved integration and closure test scripts.

---

## Modules

### `safe_test_db_client.js`

Centralized safe database client for approved destructive integration tests.

- **Not for ordinary unit/regression tests.** Ordinary `flutter test` and `pnpm test` suites must use anon/authenticated application RPC paths.
- All approved destructive fixture mutations must go through `TestSession` — which enforces fail-closed fixture ownership before any SQL is dispatched.
- **No credentials are hardcoded.** Credentials are loaded from environment variables at runtime.

### `test_isolation_guard.js`

Protected physical rehearsal resource denylist and guard functions.

- Defines the hardcoded denylist of current contaminated rehearsal IDs (second layer of defence).
- The first and primary layer is `TestSession` fixture ownership, which blocks any unregistered resource — including future physical rehearsal IDs not yet in the denylist.

---

## Credential Policy

| Credential | Required by | Available in normal test env? |
|---|---|---|
| `SUPABASE_MGMT_PAT` | `safe_test_db_client.js` admin operations | **NO** |
| `SUPABASE_SERVICE_ROLE_KEY` | Admin/migration scripts | **NO** |
| `SUPABASE_ANON_KEY` | Application paths in tests | YES |

**`SUPABASE_MGMT_PAT` and `SUPABASE_SERVICE_ROLE_KEY` must NOT appear in CI environment variables for `flutter test` or `pnpm test` jobs.**

They are supplied only via explicit operator invocation of authorized administrative/integration scripts.

This is the primary security boundary. Client-side guards (`TestSession`) are defence-in-depth.

---

## Adding a New Approved Integration Test Script

```javascript
const { TestSession, createSyntheticFixtureSet } = require('./lib/safe_test_db_client');

const session = new TestSession('MY-FEATURE-NAME');
const fixture = createSyntheticFixtureSet('MY-FEATURE');

// 1. Provision resources via RPC (not raw INSERT)
// 2. Register returned IDs:
session.registerFixture(returnedShipmentId);

// 3. Mutations only through the session:
await session.executeMutationSql(
  `UPDATE public.shipments SET ... WHERE id = '${returnedShipmentId}'`,
  [returnedShipmentId],
  'Test assertion'
);

// 4. Cleanup:
session.close();
```

## Protecting Future Physical Rehearsals

When a new clean physical rehearsal begins, add its IDs to
`PROTECTED_LIVE_RESOURCES` in `scripts/lib/test_isolation_guard.js`
before running any integration tests against the Staging environment.
