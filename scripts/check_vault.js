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
  await runSQL("SELECT extname, extversion FROM pg_extension WHERE extname LIKE '%vault%' OR extname LIKE '%sodium%'", 'VAULT EXTENSIONS');
  await runSQL("SELECT nspname FROM pg_namespace WHERE nspname LIKE '%vault%'", 'VAULT SCHEMA');
  await runSQL("CREATE EXTENSION IF NOT EXISTS supabase_vault CASCADE;", 'ENABLE VAULT');
  await runSQL("SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema='vault'", 'VAULT TABLES');
  await runSQL("SELECT routine_name FROM information_schema.routines WHERE routine_schema='vault'", 'VAULT ROUTINES');
}

main().catch(err => console.error(err));
