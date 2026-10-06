/**
 * CERELO V1 — Apply Migration 17 to Staging and Production
 */

const fs = require('fs');
const path = require('path');

const PAT = process.env.SUPABASE_MGMT_PAT;
if (!PAT) {
  console.error('[ERROR] SUPABASE_MGMT_PAT environment variable is required.');
  process.exit(1);
}
const MIGRATION_PATH = path.resolve(__dirname, '../supabase/migrations/20260817000017_align_delivery_and_payment_semantics.sql');
const MIGRATION_VERSION = '20260817000017';
const MIGRATION_NAME = 'align_delivery_and_payment_semantics';

const sqlContent = fs.readFileSync(MIGRATION_PATH, 'utf8');

async function runSQL(ref, sql, label, retries = 3) {
  const url = `https://api.supabase.com/v1/projects/${ref}/database/query`;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 30000);
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${PAT}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query: sql }),
        signal: controller.signal
      });
      clearTimeout(timeout);

      const data = await res.json().catch(() => ({}));
      console.log(`[${ref}] ${label} Status: ${res.status}`);
      if (!res.ok) {
        console.error(`[${ref}] Error:`, data);
      }
      return { ok: res.ok, data };
    } catch (e) {
      console.warn(`[${ref}] Attempt ${attempt} failed: ${e.message}`);
      if (attempt === retries) throw e;
      await new Promise(r => setTimeout(r, 2000 * attempt));
    }
  }
}

async function applyToProject(ref, projectName) {
  console.log(`\n===============================================================`);
  console.log(`Applying Migration 17 to ${projectName} (${ref})...`);
  console.log(`===============================================================`);

  // 1. Run the migration SQL
  const applyRes = await runSQL(ref, sqlContent, 'APPLY MIGRATION 17');
  if (!applyRes.ok) {
    throw new Error(`Failed to apply migration to ${projectName}`);
  }

  // 2. Record migration in schema_migrations history table
  const recordSQL = `
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('${MIGRATION_VERSION}', '${MIGRATION_NAME}')
    ON CONFLICT (version) DO UPDATE SET name = '${MIGRATION_NAME}';
  `;
  await runSQL(ref, recordSQL, 'RECORD IN SCHEMA_MIGRATIONS');

  // 3. Verify function signatures
  const verifySQL = `
    SELECT routine_name, routine_type, security_type
    FROM information_schema.routines
    WHERE routine_schema = 'public' 
      AND routine_name IN ('mark_delivered', 'record_physical_payment')
    ORDER BY routine_name;
  `;
  const verifyRes = await runSQL(ref, verifySQL, 'VERIFY ROUTINES');
  console.log(`[${ref}] Verified Routines:`, JSON.stringify(verifyRes.data, null, 2));

  // 4. Verify migration table
  const listSQL = `
    SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 5;
  `;
  const listRes = await runSQL(ref, listSQL, 'LATEST MIGRATIONS');
  console.log(`[${ref}] Latest Migrations:`, JSON.stringify(listRes.data, null, 2));
}

async function main() {
  await applyToProject('plsoyomwoqysharmuddl', 'cerelo-staging');
  await applyToProject('mgffdifedhquwiirkhyy', 'cerelo-production');
  console.log('\n✅ Migration 17 successfully applied to BOTH Staging and Production!');
}

main().catch(err => {
  console.error('Fatal Error:', err);
  process.exit(1);
});
