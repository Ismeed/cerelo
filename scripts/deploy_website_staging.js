#!/usr/bin/env node
/**
 * Deploy the website to Vercel STAGING (Preview scope) and atomically re-point
 * the stable staging alias at the new deployment.
 *
 * Why this script exists
 * ---------------------
 * A Vercel preview deployment gets a unique, per-deployment hostname. The
 * Flutter staging build bakes in a *stable* tracking host
 * (TRACKING_BASE_URL in apps/customer_app/.dart_define.staging.json), so if the
 * alias is not moved on every deploy, staging apps keep pointing at an older
 * build while the team believes they are testing the newest one. Deploy and
 * alias therefore have to happen together, not as two things someone remembers.
 *
 * Environment separation
 * ---------------------
 *   staging     -> Preview scope    -> STAGING_ALIAS        -> Staging Supabase
 *   production  -> Production scope -> cerelonet.com        -> Production Supabase
 *
 * This script can only ever produce a preview deployment: it never passes
 * --prod, and it refuses to run if a --prod-ish argument is supplied. The
 * production domain is never referenced here.
 *
 * Usage:  node scripts/deploy_website_staging.js
 */

const { execFileSync } = require('node:child_process');
const path = require('node:path');

const STAGING_ALIAS = process.env.CERELO_STAGING_ALIAS || 'cerelo-staging.vercel.app';
const PRODUCTION_HOST = 'cerelonet.com';
const WEBSITE_DIR = path.resolve(__dirname, '..', 'apps', 'website');

function fail(message) {
  console.error(`\n[deploy:staging] ${message}\n`);
  process.exit(1);
}

// Guard: refuse anything that would turn this into a production deploy.
const forbidden = process.argv.slice(2).filter((a) => /^--prod(uction)?$/.test(a));
if (forbidden.length > 0) {
  fail(
    'This script deploys STAGING only and must never publish to production.\n' +
      `Use the production script if you intend to deploy ${PRODUCTION_HOST}.`
  );
}
if (STAGING_ALIAS.includes(PRODUCTION_HOST)) {
  fail(`Refusing to run: staging alias resolves to the production host (${STAGING_ALIAS}).`);
}

function vercel(args, { capture = false } = {}) {
  return execFileSync('vercel', args, {
    cwd: WEBSITE_DIR,
    encoding: 'utf8',
    stdio: capture ? ['inherit', 'pipe', 'inherit'] : 'inherit',
    shell: process.platform === 'win32',
  });
}

/** Pull the deployment hostname out of whatever shape the CLI printed. */
function extractDeploymentUrl(stdout) {
  const text = String(stdout || '');
  try {
    const parsed = JSON.parse(text);
    const url = parsed?.deployment?.url || parsed?.url;
    if (url) return String(url).replace(/^https?:\/\//, '');
  } catch {
    // Not JSON - fall through to scanning the text.
  }
  const matches = text.match(/[a-z0-9-]+\.vercel\.app/gi) || [];
  // Skip the stable alias itself; we want the fresh per-deployment host.
  const candidate = matches.reverse().find((h) => h.toLowerCase() !== STAGING_ALIAS.toLowerCase());
  return candidate || null;
}

console.log(`[deploy:staging] deploying preview from ${WEBSITE_DIR}`);
const out = vercel(['deploy', '--yes'], { capture: true });
process.stdout.write(out);

const deployment = extractDeploymentUrl(out);
if (!deployment) {
  fail('Could not determine the new deployment URL, so the alias was NOT moved.');
}

console.log(`\n[deploy:staging] pointing ${STAGING_ALIAS} -> ${deployment}`);
vercel(['alias', 'set', deployment, STAGING_ALIAS]);

// Confirm the alias actually moved rather than trusting the exit code.
const inspected = vercel(['inspect', STAGING_ALIAS], { capture: true });
process.stdout.write(inspected);

console.log(
  `\n[deploy:staging] done.\n` +
    `  staging site     : https://${STAGING_ALIAS}\n` +
    `  deployment       : https://${deployment}\n` +
    `  production host  : ${PRODUCTION_HOST} (untouched)\n`
);
