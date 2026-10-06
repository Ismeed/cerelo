const fs = require('fs');
const path = require('path');
// Load .env.local and provide credential helpers
const { getManagementPat } = require('./lib/env_loader');

const PAT = getManagementPat();
const PROJECT_REF = 'plsoyomwoqysharmuddl';

const workerSecret = process.env.NOTIFICATION_WORKER_SECRET ||
  (fs.existsSync(path.resolve(__dirname, '.worker_secret.tmp'))
    ? fs.readFileSync(path.resolve(__dirname, '.worker_secret.tmp'), 'utf8').trim()
    : '');

/**
 * NOTE ON SUPABASE SECRETS ARCHITECTURE:
 * - Supabase automatically injects `SUPABASE_SECRET_KEYS` (a JSON dictionary containing
 *   all project API keys, e.g. 'cerelo_staging_backend_2026_08') into hosted Edge Functions.
 * - Therefore, we do NOT push a custom SUPABASE_SECRET_KEY secret.
 * - Only application-specific secrets (e.g. WORKER_SECRET_KEY) and static config
 *   (SUPABASE_URL) need to be configured here.
 */
async function setSecrets() {
  console.log('Configuring secrets in Supabase Edge Function Environment...');

  const secrets = [
    // Worker authentication secret
    { name: 'WORKER_SECRET_KEY', value: workerSecret },
    // Static project URL — required by Edge Functions
    { name: 'SUPABASE_URL', value: 'https://plsoyomwoqysharmuddl.supabase.co' },
  ];

  const resp = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/secrets`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${PAT}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(secrets)
  });

  console.log('Secrets API HTTP Status:', resp.status);
  const data = await resp.json().catch(() => ({}));
  console.log('Response:', data);
}

setSecrets().catch(err => console.error(err));
