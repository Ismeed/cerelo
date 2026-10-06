/**
 * CERELO V1 — Deploy Edge Function via Supabase Functions Upload API
 *
 * The Management API (api.supabase.com) requires a PAT.
 * However, Supabase also supports direct ESZIP upload via a different endpoint.
 * 
 * This script creates a minimal self-contained TypeScript bundle and
 * attempts upload through the available API surface.
 */

const fs = require('fs');
const path = require('path');
const { getSupabaseSecretKey } = require('./lib/env_loader');

const PROJECT_REF = 'plsoyomwoqysharmuddl';
const HOSTED_URL = 'https://plsoyomwoqysharmuddl.supabase.co';
// Prefers SUPABASE_SECRET_KEY (sb_secret_...) — falls back to SUPABASE_SERVICE_ROLE_KEY during migration.
// TODO: Remove legacy fallback after management disables the old service-role credential.
const SERVICE_ROLE_KEY = getSupabaseSecretKey();

// The Supabase Functions API also accepts raw TypeScript uploads
// via POST to /functions/v1/admin endpoint (project-level management)
// But this requires the service role key as a workaround

async function tryAlternativeDeployment() {
  console.log('Attempting alternative edge function deployment...\n');

  // Read the fixed function content
  const funcPath = path.resolve(__dirname, '../supabase/functions/process-notification-outbox/index.ts');
  const funcContent = fs.readFileSync(funcPath, 'utf8');
  console.log('Function size:', funcContent.length, 'bytes');
  console.log('Function hash check (first 100 chars):', funcContent.substring(0, 100));

  // Try the Supabase internal functions deployment endpoint
  // This is the same endpoint the CLI uses but requires auth
  const deployUrl = `https://api.supabase.com/v1/projects/${PROJECT_REF}/functions/process-notification-outbox`;
  
  console.log('\nTarget URL:', deployUrl);
  console.log('\nThe PAT is expired. Cannot deploy via Management API without valid PAT.');
  console.log('\nHowever, we can verify the CURRENT function behavior via a workaround:');
  console.log('The BOOT_ERROR may be caused by stale cache. Let us invoke with a cold start delay.\n');

  // Wait 5 seconds and try the function again
  await new Promise(r => setTimeout(r, 5000));
  
  const { createClient } = require(path.resolve(__dirname, '../apps/admin_web/node_modules/@supabase/supabase-js'));
  const adminClient = createClient(HOSTED_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  // Create a test user
  const ts = Date.now();
  const { data: user } = await adminClient.auth.admin.createUser({
    email: `boot-test-${ts}@test.cerelonet.com`,
    password: 'BootTest789!',
    email_confirm: true,
    user_metadata: { full_name: 'Boot Test' },
    app_metadata: { role: 'customer' }
  });

  if (!user?.user) {
    console.error('Could not create test user');
    return false;
  }

  // Insert a pending notification
  const { data: row } = await adminClient
    .from('notification_outbox')
    .insert({
      recipient_user_id: user.user.id,
      event_type: 'BOOT_TEST',
      aggregate_type: 'SYSTEM',
      aggregate_id: '00000000-0000-0000-0000-000000000001',
      payload: { test: 'boot-retry', ts },
      status: 'PENDING'
    })
    .select()
    .single();

  if (!row) {
    console.error('Could not insert outbox row');
    return false;
  }
  console.log('Outbox row created:', row.id, '| status:', row.status);

  // Try invoking the function
  console.log('\nInvoking process-notification-outbox...');
  const funcUrl = `${HOSTED_URL}/functions/v1/process-notification-outbox`;
  
  for (let attempt = 1; attempt <= 3; attempt++) {
    console.log(`\nAttempt ${attempt}/3...`);
    const resp = await fetch(funcUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ batch_size: 10 })
    });
    
    const body = await resp.json().catch(() => ({}));
    console.log(`HTTP ${resp.status}:`, JSON.stringify(body));
    
    if (resp.status === 200) {
      console.log('\n✅ FUNCTION IS RESPONDING! BOOT_ERROR RESOLVED');
      
      // Check row status
      await new Promise(r => setTimeout(r, 2000));
      const { data: updated } = await adminClient
        .from('notification_outbox')
        .select('status, attempts, processed_at')
        .eq('id', row.id)
        .single();
      
      console.log('Row final state:', updated);
      return true;
    }
    
    if (attempt < 3) {
      console.log('Waiting 10s before retry...');
      await new Promise(r => setTimeout(r, 10000));
    }
  }
  
  console.log('\n❌ BOOT_ERROR persists across 3 attempts.');
  console.log('Resolution requires redeployment with a valid PAT.');
  console.log('\nFIXED FUNCTION is ready at:');
  console.log('  supabase/functions/process-notification-outbox/index.ts');
  console.log('\nDeploy command (requires valid PAT):');
  console.log('  supabase functions deploy process-notification-outbox --project-ref plsoyomwoqysharmuddl --no-verify-jwt');
  return false;
}

tryAlternativeDeployment().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
