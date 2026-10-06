#!/usr/bin/env node
/**
 * Deploy the website to Vercel PRODUCTION (cerelonet.com).
 *
 * Kept as a separate entry point from the staging script so that the two can
 * never be confused, and so the staging alias logic has no way to run here.
 * This script must never touch the staging alias: staging and production are
 * backed by different Supabase projects, and pointing one at the other is the
 * highest-consequence mistake available in this codebase.
 *
 * Environment separation
 * ---------------------
 *   production  -> Production scope -> cerelonet.com   -> Production Supabase
 *   staging     -> Preview scope    -> staging alias   -> Staging Supabase
 *
 * Requires an explicit confirmation flag, because a production deploy is
 * outward-facing and irreversible from the public's point of view.
 *
 * Usage:  node scripts/deploy_website_production.js --confirm
 */

const { execFileSync } = require('node:child_process');
const path = require('node:path');

const PRODUCTION_HOST = 'cerelonet.com';
const STAGING_ALIAS = process.env.CERELO_STAGING_ALIAS || 'cerelo-staging.vercel.app';
const WEBSITE_DIR = path.resolve(__dirname, '..', 'apps', 'website');

function fail(message) {
  console.error(`\n[deploy:production] ${message}\n`);
  process.exit(1);
}

if (!process.argv.slice(2).includes('--confirm')) {
  fail(
    `This publishes to ${PRODUCTION_HOST}, which is backed by the PRODUCTION database.\n` +
      'Re-run with --confirm if that is what you intend.'
  );
}

console.log(`[deploy:production] deploying ${PRODUCTION_HOST} from ${WEBSITE_DIR}`);
execFileSync('vercel', ['deploy', '--prod', '--yes'], {
  cwd: WEBSITE_DIR,
  encoding: 'utf8',
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

console.log(
  `\n[deploy:production] done.\n` +
    `  production host : https://${PRODUCTION_HOST}\n` +
    `  staging alias   : ${STAGING_ALIAS} (deliberately untouched)\n`
);
