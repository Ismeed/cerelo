/**
 * CERELO V1 — Deploy Edge Function via Supabase Management API
 * 
 * Uses the Management REST API to deploy the process-notification-outbox 
 * edge function since the CLI is experiencing Docker-related issues.
 */

const fs = require('fs');
const path = require('path');

// We'll use axios-like fetch for multipart
const MANAGEMENT_API = 'https://api.supabase.com/v1';
const PROJECT_REF = 'plsoyomwoqysharmuddl';
const PAT = process.env.SUPABASE_MGMT_PAT;
if (!PAT) {
  console.error('[ERROR] SUPABASE_MGMT_PAT environment variable is required.');
  process.exit(1);
}
const FUNCTION_SLUG = 'process-notification-outbox';

async function deployEdgeFunction() {
  console.log('Deploying process-notification-outbox via Management API...\n');
  
  // Read function files
  const mainFuncPath = path.resolve(__dirname, '../supabase/functions/process-notification-outbox/index.ts');
  const corsFuncPath = path.resolve(__dirname, '../supabase/functions/_shared/cors.ts');
  
  const mainFuncContent = fs.readFileSync(mainFuncPath, 'utf8');
  const corsFuncContent = fs.readFileSync(corsFuncPath, 'utf8');
  
  console.log('Main function size:', mainFuncContent.length, 'bytes');
  console.log('CORS shared size:', corsFuncContent.length, 'bytes');
  
  // Build an ESZIP bundle manually — the simplest approach is to 
  // use the Functions API with base64-encoded content or ESZIP
  // Supabase Management API /v1/projects/{ref}/functions/{slug} PATCH/POST
  
  // Try using the update endpoint with raw body (single file deployment)
  // The API accepts a multipart/form-data or raw body with metadata
  
  // First check existing function
  const checkResponse = await fetch(
    `${MANAGEMENT_API}/projects/${PROJECT_REF}/functions/${FUNCTION_SLUG}`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${PAT}`
      }
    }
  );
  
  console.log('Function check status:', checkResponse.status);
  if (checkResponse.ok) {
    const funcData = await checkResponse.json();
    console.log('Existing function:', JSON.stringify(funcData, null, 2));
  } else {
    const errBody = await checkResponse.text();
    console.log('Function check error body:', errBody);
  }
  
  // The Supabase Management API for deploying functions needs ESZIP format
  // Let's check if we can use the secrets/env to understand what's causing BOOT_ERROR
  
  // Check function secrets/env vars
  const secretsResponse = await fetch(
    `${MANAGEMENT_API}/projects/${PROJECT_REF}/functions/${FUNCTION_SLUG}/secrets`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${PAT}`
      }
    }
  );
  
  console.log('\nSecrets endpoint status:', secretsResponse.status);
  
  // Check project secrets (env vars)
  const projSecretsResponse = await fetch(
    `${MANAGEMENT_API}/projects/${PROJECT_REF}/secrets`,
    {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${PAT}`
      }
    }
  );
  
  console.log('Project secrets status:', projSecretsResponse.status);
  if (projSecretsResponse.ok) {
    const secrets = await projSecretsResponse.json();
    console.log('Configured secrets (names only):');
    secrets.forEach(s => console.log(' -', s.name));
  }
}

deployEdgeFunction().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
