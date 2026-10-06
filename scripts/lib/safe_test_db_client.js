/**
 * CERELO V1 — CENTRALIZED SAFE TEST DATABASE CLIENT
 * Location: scripts/lib/safe_test_db_client.js
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * PURPOSE
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * All approved integration/closure test scripts that require direct database
 * access MUST use this client for destructive fixture operations.
 *
 * Ordinary unit and regression tests should use anon/authenticated application
 * paths (RPCs) rather than this client, and do NOT receive privileged creds.
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * SECURITY MODEL
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * - No credentials are hardcoded here or in any module that imports this file.
 * - Credentials are supplied ONLY through named environment variables.
 * - Ordinary `flutter test` / `pnpm test` do NOT receive SUPABASE_MGMT_PAT
 *   or SUPABASE_SERVICE_ROLE_KEY in their runtime environment.
 * - Only explicitly authorized administrative/integration scripts receive those
 *   environment variables, and only when deliberately invoked by an operator.
 * - Client-side guards protect compliant scripts. Arbitrary untrusted code that
 *   independently obtains privileged credentials can bypass these guards —
 *   therefore keeping credentials out of test environments is the primary
 *   control. This guard is defence-in-depth, not the security boundary.
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * INVARIANT: FIXTURE OWNERSHIP
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * Every destructive mutation (UPDATE/DELETE/lifecycle transition) executed
 * through this client MUST prove that the target was created by the current
 * TestSession. An unregistered resource — including any future live physical
 * rehearsal IDs not yet known — will be blocked fail-closed.
 *
 * The hardcoded denylist (test_isolation_guard.js) is a second layer for the
 * current contaminated physical rehearsal IDs.
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * USAGE (integration/closure scripts only)
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 *
 *   const { TestSession, createSyntheticFixtureSet } = require('./lib/safe_test_db_client');
 *
 *   const session = new TestSession('MY-TEST-NAME');
 *   const fixture = createSyntheticFixtureSet('MY-TEST-NAME');
 *
 *   // 1. Provision synthetic resources (via RPC — never via direct INSERT here)
 *   //    Register the returned IDs:
 *   session.registerFixture(fixture.shipmentId);
 *
 *   // 2. Execute mutations only through the session:
 *   await session.executeMutationSql(
 *     `UPDATE public.shipments SET ... WHERE id = '${fixture.shipmentId}'`,
 *     [fixture.shipmentId],
 *     'Test assertion update'
 *   );
 *
 *   // 3. Close and discard:
 *   session.close();
 *
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 */

'use strict';

const path = require('path');
// Load .env.local and provide credential helpers (SUPABASE_SECRET_KEY with legacy fallback)
const { getSupabaseSecretKey, getManagementPat, validateSecretKeyPresence } = require('./env_loader.js');
const {
  PROTECTED_LIVE_RESOURCES,
  ALL_PROTECTED_IDENTIFIERS,
  assertNotProtected,
  validateSafeTestQuery,
  createSyntheticFixtureSet,
  assertSyntheticOwnership,
  TestIsolationViolationError
} = require('./test_isolation_guard.js');

// ─── Error Types ─────────────────────────────────────────────────────────────

class FixtureOwnershipViolationError extends Error {
  constructor(message, targetId) {
    super(`[FAIL-CLOSED FIXTURE OWNERSHIP VIOLATION] ${message} (Target: ${targetId})`);
    this.name = 'FixtureOwnershipViolationError';
    this.targetId = targetId;
  }
}

class UnsafeQueryPatternError extends Error {
  constructor(message) {
    super(`[UNSAFE DESTRUCTIVE PATTERN] ${message}`);
    this.name = 'UnsafeQueryPatternError';
  }
}

// ─── TestSession ─────────────────────────────────────────────────────────────

/**
 * A TestSession represents a single isolated integration test run.
 * It owns the set of synthetic fixtures provisioned during setup,
 * and enforces that only those fixtures may be mutated.
 */
class TestSession {
  /**
   * @param {string} testRunName - Human-readable name for this test run (e.g. 'RECONCILIATION-FLOW')
   */
  constructor(testRunName = 'TEST') {
    this.testRunId = [
      'TR',
      testRunName.toUpperCase().replace(/[^A-Z0-9]/g, '-').slice(0, 20),
      Date.now().toString(36).toUpperCase(),
      Math.random().toString(36).substring(2, 6).toUpperCase()
    ].join('-');
    this._ownedIds = new Set();      // exact string match
    this._ownedUpper = new Set();    // uppercase match
    this.isClosed = false;
    this._startedAt = new Date().toISOString();
  }

  /**
   * Registers a newly provisioned synthetic fixture ID under this session.
   * Fails closed if the ID matches any protected physical rehearsal resource.
   * @param {string} idOrCode
   */
  registerFixture(idOrCode) {
    if (!idOrCode) return;
    const str = String(idOrCode).trim();

    // Defence-in-depth: never allow protected live IDs to be registered as synthetic
    assertNotProtected(str, `TestSession.registerFixture (${this.testRunId})`);

    this._ownedIds.add(str);
    this._ownedUpper.add(str.toUpperCase());
  }

  /**
   * Asserts session ownership of all listed target IDs before a mutation.
   * @param {string|string[]} targetIds
   * @param {string} context
   */
  assertOwnership(targetIds, context = 'Mutation') {
    if (this.isClosed) {
      throw new FixtureOwnershipViolationError(
        `TestSession '${this.testRunId}' is already closed. No further mutations permitted.`,
        this.testRunId
      );
    }

    const targets = Array.isArray(targetIds) ? targetIds : [targetIds];
    if (targets.length === 0) {
      throw new FixtureOwnershipViolationError(
        'Mutation must specify at least one explicit target fixture ID.',
        'NONE'
      );
    }

    for (const target of targets) {
      const str = String(target).trim();

      // 1. Protected denylist check (second layer of defence)
      assertNotProtected(str, context);

      // 2. Session ownership check (primary layer)
      if (!this._ownedIds.has(str) && !this._ownedUpper.has(str.toUpperCase())) {
        throw new FixtureOwnershipViolationError(
          `Target '${str}' does not belong to test run '${this.testRunId}'. ` +
          `Only fixtures registered via session.registerFixture() may be mutated. ` +
          `This blocks arbitrary existing Staging resources, cross-session fixtures, ` +
          `and any future physical rehearsal IDs not yet in the denylist.`,
          str
        );
      }
    }
  }

  /**
   * Validates and executes a mutation SQL through the safe DB connection.
   * Requires proof of fixture ownership for every listed target ID.
   *
   * @param {string} sql - The mutation SQL to execute
   * @param {string[]} targetFixtureIds - IDs that the SQL mutates (must be session-owned)
   * @param {string} context - Human-readable label for logging
   * @returns {Promise<any>}
   */
  async executeMutationSql(sql, targetFixtureIds, context = 'Test Mutation') {
    this.assertOwnership(targetFixtureIds, context);

    // Block dangerous dynamic discovery patterns
    if (/ORDER\s+BY\s+created_at\s+DESC\s+LIMIT\s+1/i.test(sql)) {
      throw new UnsafeQueryPatternError(
        `Forbidden pattern 'ORDER BY created_at DESC LIMIT 1' detected in mutation. ` +
        `Tests must target explicit fixture IDs returned from their own setup, not discover live records dynamically.`
      );
    }

    return await _executeSqlViaManagementApi(sql);
  }

  /**
   * Executes a read-only SELECT query. Rejects any mutation keywords.
   * @param {string} sql
   * @returns {Promise<any>}
   */
  async executeReadSql(sql) {
    if (/\b(UPDATE|DELETE|INSERT|ALTER|TRUNCATE|DROP)\b/i.test(sql)) {
      throw new Error(
        '[safe_test_db_client] Mutation keyword in executeReadSql. ' +
        'Use executeMutationSql with proven session ownership for mutations.'
      );
    }
    return await _executeSqlViaManagementApi(sql);
  }

  /**
   * Closes this session. No further mutations are permitted after close().
   */
  close() {
    this.isClosed = true;
    this._ownedIds.clear();
    this._ownedUpper.clear();
  }

  get id() { return this.testRunId; }
  get startedAt() { return this._startedAt; }
}

// ─── Internal SQL Transport ───────────────────────────────────────────────────

/**
 * Low-level SQL dispatch via Supabase Management API.
 * Uses SUPABASE_MGMT_PAT — the Management API credential.
 * This is SEPARATE from SUPABASE_SECRET_KEY (Data API).
 * Credentials are loaded via env_loader (reads .env.local) or process.env.
 * NEVER hardcode credentials here or in any caller.
 *
 * IMPORTANT: SUPABASE_MGMT_PAT must NOT be present in ordinary
 * flutter test / pnpm test environments.
 *
 * @param {string} query
 * @param {number} retries
 * @returns {Promise<any>}
 */
async function _executeSqlViaManagementApi(query, retries = 3) {
  const STAG_REF = process.env.SUPABASE_PROJECT_REF || 'plsoyomwoqysharmuddl';
  // getManagementPat() loads from .env.local via env_loader and throws clearly if absent
  const PAT = getManagementPat();

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const res = await fetch(
        `https://api.supabase.com/v1/projects/${STAG_REF}/database/query`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${PAT}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ query })
        }
      );

      if (!res.ok) {
        const errText = await res.text();
        throw new Error(`SQL Error (HTTP ${res.status}): ${errText}`);
      }
      return await res.json();
    } catch (err) {
      // Propagate SQL errors immediately; retry only on transient network issues
      if (attempt === retries || err.message.startsWith('SQL Error')) {
        throw err;
      }
      await new Promise(r => setTimeout(r, 1500 * attempt));
    }
  }
}

// ─── Exports ─────────────────────────────────────────────────────────────────

module.exports = {
  // TestSession class — primary interface for approved destructive integration tests
  TestSession,

  // Re-export fixture utilities from the shared guard
  createSyntheticFixtureSet,
  assertSyntheticOwnership,
  assertNotProtected,
  validateSafeTestQuery,

  // Protected resource registry (read-only)
  PROTECTED_LIVE_RESOURCES,
  ALL_PROTECTED_IDENTIFIERS,

  // Error classes
  TestIsolationViolationError,
  FixtureOwnershipViolationError,
  UnsafeQueryPatternError
};
