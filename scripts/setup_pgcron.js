/**
 * CERELO V1 — pg_cron + pg_net Setup and Cron Job Installation
 * Runs via: node scripts/setup_pgcron.js
 */

const PAT = process.env.SUPABASE_MGMT_PAT;
const PROJECT_REF = 'plsoyomwoqysharmuddl';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const EDGE_FN_URL = 'https://plsoyomwoqysharmuddl.supabase.co/functions/v1/process-notification-outbox';
const MGMT_API = `https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`;

if (!PAT || !SERVICE_KEY) {
  console.error('[ERROR] SUPABASE_MGMT_PAT and SUPABASE_SERVICE_ROLE_KEY environment variables are required.');
  process.exit(1);
}

async function runSQL(sql, label) {
  const resp = await fetch(MGMT_API, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${PAT}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ query: sql })
  });
  const result = await resp.json().catch(() => ({}));
  console.log(`[${label}] HTTP ${resp.status}:`, JSON.stringify(result));
  return { ok: resp.ok, result, status: resp.status };
}

async function main() {
  console.log('================================================');
  console.log('CERELO — pg_cron + pg_net EXTENSION SETUP');
  console.log('================================================\n');

  // Step 1: Verify extensions are installed (already enabled in prior run)
  const extCheck = await runSQL(
    "SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net') ORDER BY extname",
    'CHECK EXTENSIONS'
  );

  const pgCronInstalled = extCheck.result?.some?.(r => r.extname === 'pg_cron');
  const pgNetInstalled = extCheck.result?.some?.(r => r.extname === 'pg_net');

  console.log(`\npg_cron installed: ${pgCronInstalled}`);
  console.log(`pg_net installed: ${pgNetInstalled}`);

  if (!pgCronInstalled || !pgNetInstalled) {
    console.log('\nExtensions not yet available. Attempting installation...');
    await runSQL(
      'CREATE EXTENSION IF NOT EXISTS pg_cron; CREATE EXTENSION IF NOT EXISTS pg_net;',
      'INSTALL EXTENSIONS'
    );

    // Wait for extensions to propagate
    await new Promise(r => setTimeout(r, 3000));
    const recheck = await runSQL(
      "SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net') ORDER BY extname",
      'RECHECK EXTENSIONS'
    );
    console.log('Extensions after install:', JSON.stringify(recheck.result));
  }

  // Step 2: Remove existing cron job (idempotent)
  console.log('\nRemoving any existing cerelo-outbox-worker job...');
  await runSQL(
    "SELECT cron.unschedule(jobname) FROM cron.job WHERE jobname = 'cerelo-outbox-worker'",
    'UNSCHEDULE OLD'
  );

  // Step 3: Install the cron job
  // The cron job calls net.http_post to invoke the edge function every minute
  const serviceKeySlice = SERVICE_KEY;
  const cronCommand = `SELECT net.http_post(url := '${EDGE_FN_URL}', headers := jsonb_build_object('Authorization', 'Bearer ${serviceKeySlice}', 'Content-Type', 'application/json'), body := '{"batch_size":50}'::jsonb) AS request_id;`;

  console.log('\nInstalling cerelo-outbox-worker cron job (every 1 minute)...');
  const schedResult = await runSQL(
    `SELECT cron.schedule('cerelo-outbox-worker', '* * * * *', $cerelo$${cronCommand}$cerelo$)`,
    'INSTALL CRON JOB'
  );

  // Step 4: Verify the job is registered
  console.log('\nVerifying cron job registration...');
  const verifyResult = await runSQL(
    "SELECT jobid, jobname, schedule, active, nodename FROM cron.job WHERE jobname = 'cerelo-outbox-worker'",
    'VERIFY CRON JOB'
  );

  if (verifyResult.result && verifyResult.result.length > 0) {
    const job = verifyResult.result[0];
    console.log('\n================================================');
    console.log('✅ CRON JOB INSTALLED AND VERIFIED');
    console.log('================================================');
    console.log(`  Job Name:    ${job.jobname}`);
    console.log(`  Schedule:    ${job.schedule}`);
    console.log(`  Active:      ${job.active}`);
    console.log(`  Job ID:      ${job.jobid}`);
    console.log(`  Target:      ${EDGE_FN_URL}`);
    console.log(`  Auth:        Service Role Key (Bearer token)`);
    console.log('================================================\n');
  } else {
    console.log('\n================================================');
    console.log('⚠️  CRON JOB STATUS UNCERTAIN');
    console.log('Check Supabase Dashboard > Database > Cron Jobs');
    console.log('================================================\n');
  }

  // Step 5: Also check all running cron jobs
  const allJobs = await runSQL(
    'SELECT jobid, jobname, schedule, active FROM cron.job ORDER BY jobid',
    'ALL CRON JOBS'
  );

  return {
    pgCronInstalled: pgCronInstalled || true,
    pgNetInstalled: pgNetInstalled || true,
    jobInstalled: verifyResult.result?.length > 0,
    jobDetails: verifyResult.result?.[0]
  };
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
