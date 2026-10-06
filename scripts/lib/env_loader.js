/**
 * CERELO V1 — ENVIRONMENT LOADER FOR NODE SCRIPTS
 * Location: scripts/lib/env_loader.js
 *
 * Loads environment variables from the root .env.local file if present.
 * This provides a safe, git-ignored local credential source for authorized
 * administrative/integration scripts.
 *
 * IMPORTANT:
 * - .env.local is git-ignored at the root .gitignore.
 * - Ordinary flutter test / pnpm test do NOT use this loader.
 * - Only explicitly authorized admin scripts require() this module.
 * - NEVER hardcode credentials in source files — use this loader.
 *
 * CREDENTIAL SEPARATION:
 * ┌─────────────────────────────────────────────────────────────────────┐
 * │  SUPABASE_MGMT_PAT        = Supabase Management API token          │
 * │                             Used for: schema queries, secrets mgmt │
 * │                             NOT replaced by SUPABASE_SECRET_KEY    │
 * │                                                                     │
 * │  SUPABASE_SECRET_KEY      = New sb_secret_... staging server key   │
 * │                             Used for: server/data API access       │
 * │                             (Legacy service role fallback eradicated)│
 * │                                                                     │
 * │  SUPABASE_PUBLISHABLE_KEY = New sb_publishable_... client key      │
 * │                             Used for: client-safe API access       │
 * │                             (Legacy anon fallback eradicated)       │
 * └─────────────────────────────────────────────────────────────────────┘
 */

'use strict';

const path = require('path');
const fs = require('fs');

// Path to the root .env.local — this is git-ignored
const ROOT_ENV_LOCAL = path.resolve(__dirname, '../../.env.local');

// Load .env.local into process.env if file exists
if (fs.existsSync(ROOT_ENV_LOCAL)) {
  const raw = fs.readFileSync(ROOT_ENV_LOCAL, 'utf8');
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    // Skip blanks and comments
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx < 1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const val = trimmed.slice(eqIdx + 1).trim();
    // Only set if not already defined in the process environment
    if (!process.env[key]) {
      process.env[key] = val;
    }
  }
}

/**
 * Returns the canonical server-side Supabase data API key (SUPABASE_SECRET_KEY).
 * Legacy SUPABASE_SERVICE_ROLE_KEY fallback is completely eradicated.
 */
function getSupabaseSecretKey() {
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!key) {
    throw new Error(
      '[env_loader] SUPABASE_SECRET_KEY is not set. ' +
      'Ensure .env.local contains SUPABASE_SECRET_KEY with the sb_secret_... key, ' +
      'or supply it as an environment variable.'
    );
  }
  return key;
}

/**
 * Returns the Supabase Management API PAT.
 * Completely separate from the data API secret key.
 */
function getManagementPat() {
  const pat = process.env.SUPABASE_MGMT_PAT;
  if (!pat) {
    throw new Error(
      '[env_loader] SUPABASE_MGMT_PAT is not set. ' +
      'This is a separate Management API credential from the data API key.'
    );
  }
  return pat;
}

/**
 * Validates SUPABASE_SECRET_KEY without printing its value.
 * Returns { valid: boolean, usingNew: boolean, reason: string }
 */
function validateSecretKeyPresence() {
  const newKey = process.env.SUPABASE_SECRET_KEY;

  if (newKey) {
    const looksLikeSecretKey = newKey.startsWith('sb_secret_') || newKey.startsWith('sbp_') || newKey.length > 40;
    return {
      valid: true,
      usingNew: true,
      hasLegacyFallback: false,
      reason: looksLikeSecretKey
        ? 'SUPABASE_SECRET_KEY is present and format looks valid'
        : 'SUPABASE_SECRET_KEY is present but format may be unexpected'
    };
  } else {
    return {
      valid: false,
      usingNew: false,
      hasLegacyFallback: false,
      reason: 'FAIL: SUPABASE_SECRET_KEY is not set. Legacy fallback is eradicated.'
    };
  }
}

/**
 * Returns the canonical client-safe Supabase publishable API key (sb_publishable_...).
 * Legacy anon fallback is completely eradicated.
 */
function getSupabasePublishableKey() {
  const key = process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!key) {
    throw new Error(
      '[env_loader] SUPABASE_PUBLISHABLE_KEY is not set. ' +
      'Ensure .env.local contains SUPABASE_PUBLISHABLE_KEY with the sb_publishable_... key.'
    );
  }
  return key;
}

const CERELO_STAGING_SECRET_KEY_NAME = 'cerelo_staging_backend_2026_08';

module.exports = {
  getSupabaseSecretKey,
  getSupabasePublishableKey,
  getManagementPat,
  validateSecretKeyPresence,
  ROOT_ENV_LOCAL,
  CERELO_STAGING_SECRET_KEY_NAME,
};
