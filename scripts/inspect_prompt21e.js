const PAT = process.env.SUPABASE_MGMT_PAT;
if (!PAT) {
  console.error('[ERROR] SUPABASE_MGMT_PAT environment variable is required.');
  process.exit(1);
}
const PROJECT_REF = 'plsoyomwoqysharmuddl';
const API = `https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`;

async function runSQL(sql, label) {
  const r = await fetch(API, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${PAT}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: sql })
  });
  const data = await r.json();
  console.log(`=== ${label} ===`);
  console.log(JSON.stringify(data, null, 2));
  return data;
}

async function main() {
  await runSQL("SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_schema='public' AND table_name='notification_outbox' ORDER BY ordinal_position", 'OUTBOX COLUMNS');
  await runSQL("SELECT extname, extversion FROM pg_extension WHERE extname IN ('vault', 'pg_cron', 'pg_net', 'pgsodium', 'supabase_vault')", 'VAULT & EXTENSIONS');
  await runSQL("SELECT * FROM cron.job", 'CURRENT CRON JOBS');
  await runSQL("SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10", 'CRON RUN DETAILS');
  await runSQL("SELECT * FROM notification_outbox ORDER BY created_at DESC LIMIT 5", 'RECENT NOTIFICATION OUTBOX ROWS');
}

main().catch(err => console.error(err));
