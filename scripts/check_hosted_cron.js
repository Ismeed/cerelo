/**
 * CERELO V1 — CHECK HOSTED DATABASE EXTENSIONS AND CRON STATUS
 */

const path = require('path');
const { createClient } = require(path.resolve(__dirname, '../apps/admin_web/node_modules/@supabase/supabase-js'));
const { getSupabaseSecretKey } = require('./lib/env_loader');

const HOSTED_URL = 'https://plsoyomwoqysharmuddl.supabase.co';
// Prefers SUPABASE_SECRET_KEY (sb_secret_...) — falls back to SUPABASE_SERVICE_ROLE_KEY during migration.
// TODO: Remove legacy fallback after management disables the old service-role credential.
const HOSTED_SERVICE_ROLE_KEY = getSupabaseSecretKey();

const adminClient = createClient(HOSTED_URL, HOSTED_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function checkCronSetup() {
  console.log('===============================================================');
  console.log('CERELO — HOSTED DATABASE EXTENSIONS & CRON INSPECTION');
  console.log('===============================================================\n');

  // 1. Check installed extensions via RPC that runs raw SQL
  const { data: extData, error: extErr } = await adminClient.rpc('run_system_integrity_checks');
  console.log('System integrity (confirms DB connection):', !extErr ? 'healthy' : extErr.message);

  // 2. Try to query cron jobs
  const { data: cronJobs, error: cronErr } = await adminClient
    .schema('cron')
    .from('job')
    .select('jobid, schedule, command, nodename, active, jobname');
  
  if (cronErr) {
    console.log('\npg_cron.job query error:', cronErr.message);
    console.log('-> pg_cron extension may not be enabled on this project plan');
  } else {
    console.log('\nActive cron jobs in cron.job table:', cronJobs);
  }

  // 3. Check pg_net extension
  const { data: netData, error: netErr } = await adminClient
    .rpc('check_extension_exists', { ext_name: 'pg_net' });
  
  if (netErr) {
    console.log('pg_net RPC check error:', netErr.message);
  } else {
    console.log('pg_net available:', netData);
  }
}

checkCronSetup().catch(err => {
  console.error('Error:', err.message);
});
