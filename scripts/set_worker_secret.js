const crypto = require('crypto');
const PAT = process.env.SUPABASE_MGMT_PAT;
const PROJECT_REF = 'plsoyomwoqysharmuddl';

if (!PAT) {
  console.error('[ERROR] SUPABASE_MGMT_PAT environment variable is required.');
  process.exit(1);
}

// Generate a high-entropy dedicated worker secret
const WORKER_SECRET = 'crl_worker_' + crypto.randomBytes(24).toString('hex');

async function setSecrets() {
  console.log('Configuring WORKER_SECRET_KEY in Supabase Edge Function Secrets...');
  const resp = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/secrets`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${PAT}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify([
      { name: 'WORKER_SECRET_KEY', value: WORKER_SECRET }
    ])
  });

  console.log('Secrets API HTTP Status:', resp.status);
  const data = await resp.json().catch(() => ({}));
  console.log('Response:', data);
  return WORKER_SECRET;
}

setSecrets().then(secret => {
  console.log('Successfully configured worker secret.');
  // Write secret to a local temporary config file for the migration script to read
  const fs = require('fs');
  fs.writeFileSync('scripts/.worker_secret.tmp', secret, 'utf8');
}).catch(err => console.error(err));
