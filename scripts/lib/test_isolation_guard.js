/**
 * CERELO TEST ISOLATION & LIVE REHEARSAL PROTECTION GUARD
 * Location: scripts/lib/test_isolation_guard.js
 *
 * Invariant: Approved automated test suites and fixture runners
 * must NEVER mutate or target live physical rehearsal resources.
 *
 * Violations fail closed immediately.
 *
 * ─── Physical Rehearsal Classification ────────────────────────────────────────
 * Current rehearsal status: PHYSICAL_OPERATIONAL_REHEARSAL_CONTAMINATED
 * (Contaminated because automated testing ran through destination states
 * and was partially restored via SQL. Physical Kano departure events remain
 * authentic. Authoritative status remains IN_TRANSIT until Katsina arrival.)
 */

'use strict';

// ─── Protected Physical Rehearsal Resource Denylist ───────────────────────────
// These are DEFENCE-IN-DEPTH for the CURRENT contaminated rehearsal only.
// The PRIMARY protection is TestSession fixture ownership — which blocks
// ANY unregistered resource, including future rehearsal IDs not yet listed here.

const PROTECTED_LIVE_RESOURCES = Object.freeze({
  SHIPMENT_IDS:       ['09e1e37b-6c6e-4961-a179-aa1f1efb68a1'],
  PARCEL_IDS:         ['553f4d19-1446-43ec-b8d9-4f256df4058b'],
  BATCH_IDS:          ['9df81e1c-8f38-4e8e-abbb-d78d995d6f05'],
  BATCH_REFERENCES:   ['BAT-E3TQ-HXE2'],
  BATCH_QR_TOKENS:    ['BQR-T57J-2FUN-AXRM'],
  DELIVERY_CODES:     ['CRL-EXVG-VUSE'],
  PARCEL_QR_TOKENS:   ['PQR-35CH-EVHD-7ABS'],
  TRANSIT_RUN_IDS:    ['97bdf473-5235-4c7d-9352-aa9ed161ea26'],
  CUSTOMER_USER_IDS:  ['a7c6590b-5675-48eb-a0f3-f9c9c13fb310'] // Ismail Said (Sender)
});

const ALL_PROTECTED_IDENTIFIERS = Object.freeze([
  ...PROTECTED_LIVE_RESOURCES.SHIPMENT_IDS,
  ...PROTECTED_LIVE_RESOURCES.PARCEL_IDS,
  ...PROTECTED_LIVE_RESOURCES.BATCH_IDS,
  ...PROTECTED_LIVE_RESOURCES.BATCH_REFERENCES,
  ...PROTECTED_LIVE_RESOURCES.BATCH_QR_TOKENS,
  ...PROTECTED_LIVE_RESOURCES.DELIVERY_CODES,
  ...PROTECTED_LIVE_RESOURCES.PARCEL_QR_TOKENS,
  ...PROTECTED_LIVE_RESOURCES.TRANSIT_RUN_IDS,
  ...PROTECTED_LIVE_RESOURCES.CUSTOMER_USER_IDS
]);

// ─── Error Types ──────────────────────────────────────────────────────────────

class TestIsolationViolationError extends Error {
  constructor(message, targetIdentifier) {
    super(`[FATAL TEST ISOLATION VIOLATION] ${message} Target: ${targetIdentifier}`);
    this.name = 'TestIsolationViolationError';
    this.targetIdentifier = targetIdentifier;
  }
}

// ─── Guard Functions ──────────────────────────────────────────────────────────

/**
 * Asserts that a target identifier (UUID, delivery code, batch ref, etc.)
 * is NOT a protected physical rehearsal resource.
 * Fails closed immediately on match.
 */
function assertNotProtected(identifier, context = 'Test execution') {
  if (!identifier) return;
  const idStr = String(identifier).trim().toUpperCase();

  for (const protectedId of ALL_PROTECTED_IDENTIFIERS) {
    if (idStr === protectedId.toUpperCase() || idStr.includes(protectedId.toUpperCase())) {
      throw new TestIsolationViolationError(
        `Automated test attempted to target protected live physical resource during '${context}'. ` +
        `Tests must use synthetic fixtures only!`,
        identifier
      );
    }
  }
}

/**
 * Validates a SQL query string before execution.
 * Fails closed if the query:
 * - attempts to mutate a protected physical resource, or
 * - uses un-scoped latest-record discovery patterns (ORDER BY created_at DESC LIMIT 1).
 */
function validateSafeTestQuery(query, context = 'SQL Execution') {
  if (!query || typeof query !== 'string') return;

  const isMutation = /\b(UPDATE|DELETE|INSERT|ALTER|TRUNCATE|DROP)\b/i.test(query);

  if (isMutation) {
    // Check for protected identifiers in mutation SQL
    for (const protectedId of ALL_PROTECTED_IDENTIFIERS) {
      if (query.toLowerCase().includes(protectedId.toLowerCase())) {
        throw new TestIsolationViolationError(
          `Mutation SQL contains protected physical rehearsal identifier during '${context}'. Operation aborted.`,
          protectedId
        );
      }
    }

    // Disallow un-scoped destructive latest-record discovery
    if (/SELECT\s+id\s+FROM\s+public\.(shipments|batches|parcels)\s+ORDER\s+BY\s+created_at\s+DESC\s+LIMIT\s+1/i.test(query)) {
      throw new TestIsolationViolationError(
        `Disallowed destructive pattern 'ORDER BY created_at DESC LIMIT 1' detected. ` +
        `Automated tests must target synthetic fixture IDs only!`,
        'DYNAMIC_LATEST_SELECTION'
      );
    }
  }
}

// ─── Synthetic Fixture Utilities ──────────────────────────────────────────────

/**
 * Creates a set of deterministic synthetic fixture identifiers for an isolated
 * test run. All IDs are clearly synthetic (never resemble real UUIDs or live codes).
 */
function createSyntheticFixtureSet(testRunName = 'AUTO') {
  const timestamp = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).substring(2, 6).toUpperCase();
  const testTag = `${testRunName}-${timestamp}-${rand}`;

  return Object.freeze({
    shipmentId:     `11111111-2222-3333-4444-${rand.toLowerCase().padStart(12, '0')}`,
    parcelId:       `22222222-3333-4444-5555-${rand.toLowerCase().padStart(12, '0')}`,
    batchId:        `33333333-4444-5555-6666-${rand.toLowerCase().padStart(12, '0')}`,
    transitRunId:   `44444444-5555-6666-7777-${rand.toLowerCase().padStart(12, '0')}`,
    batchReference: `BAT-SYN-${testTag}`,
    batchQrToken:   `BQR-SYN-${testTag}`,
    deliveryCode:   `CRL-SYN-${testTag}`,
    parcelQrToken:  `PQR-SYN-${testTag}`,
    isSynthetic:    true
  });
}

/**
 * Asserts that a resource is synthetic and not a protected live resource.
 * Use before teardown/cleanup to prevent accidental live data deletion.
 */
function assertSyntheticOwnership(fixture, context = 'Test fixture teardown') {
  if (!fixture || !fixture.isSynthetic) {
    throw new TestIsolationViolationError(
      `Fixture ownership assertion failed during '${context}'. ` +
      `Target is not recognized as a synthetic test fixture.`,
      JSON.stringify(fixture)
    );
  }
  assertNotProtected(fixture.shipmentId,     context);
  assertNotProtected(fixture.parcelId,       context);
  assertNotProtected(fixture.batchId,        context);
  assertNotProtected(fixture.batchReference, context);
  assertNotProtected(fixture.deliveryCode,   context);
}

// ─── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
  PROTECTED_LIVE_RESOURCES,
  ALL_PROTECTED_IDENTIFIERS,
  assertNotProtected,
  validateSafeTestQuery,
  createSyntheticFixtureSet,
  assertSyntheticOwnership,
  TestIsolationViolationError
};
