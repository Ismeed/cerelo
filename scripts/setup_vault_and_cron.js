const fs = require('fs');
const path = require('path');
const PAT = process.env.SUPABASE_MGMT_PAT;
const PROJECT_REF = 'plsoyomwoqysharmuddl';
const API = `https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`;
const EDGE_FN_URL = 'https://plsoyomwoqysharmuddl.supabase.co/functions/v1/process-notification-outbox';

if (!PAT) {
  console.error('[ERROR] SUPABASE_MGMT_PAT environment variable is required.');
  process.exit(1);
}

const workerSecret = process.env.NOTIFICATION_WORKER_SECRET || (fs.existsSync(path.resolve(__dirname, '.worker_secret.tmp')) ? fs.readFileSync(path.resolve(__dirname, '.worker_secret.tmp'), 'utf8').trim() : '');

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
  console.log('1. Storing worker secret in Supabase Vault...');
  // Vault secret creation
  const vaultSQL = `
    -- Remove any old secret with this name
    DELETE FROM vault.secrets WHERE name = 'cerelo_notification_worker_secret';
    
    -- Insert new secret into Vault
    SELECT vault.create_secret(
      '${workerSecret}',
      'cerelo_notification_worker_secret',
      'Dedicated authentication secret for Cerelo notification worker cron'
    );
  `;
  await runSQL(vaultSQL, 'VAULT STORE SECRET');

  console.log('2. Verifying secret retrieval from vault.decrypted_secrets...');
  await runSQL(`
    SELECT name, description, (decrypted_secret IS NOT NULL) AS secret_present, length(decrypted_secret) as secret_len
    FROM vault.decrypted_secrets
    WHERE name = 'cerelo_notification_worker_secret'
  `, 'VAULT VERIFY SECRET');

  console.log('3. Creating secure definer function trigger_notification_outbox_worker()...');
  const triggerFnSQL = `
    CREATE OR REPLACE FUNCTION public.trigger_notification_outbox_worker()
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, vault, net
    AS $$
    DECLARE
      worker_secret text;
      target_url text := '${EDGE_FN_URL}';
    BEGIN
      -- Retrieve secret securely from Supabase Vault
      SELECT decrypted_secret INTO worker_secret
      FROM vault.decrypted_secrets
      WHERE name = 'cerelo_notification_worker_secret'
      LIMIT 1;

      IF worker_secret IS NULL THEN
        RAISE WARNING 'Cerelo notification worker secret not found in Vault';
        RETURN;
      END IF;

      -- Dispatch authenticated HTTP POST via pg_net
      PERFORM net.http_post(
        url := target_url,
        headers := jsonb_build_object(
          'Authorization', 'Bearer ' || worker_secret,
          'Content-Type', 'application/json'
        ),
        body := '{"batch_size": 50}'::jsonb
      );
    END;
    $$;

    REVOKE ALL ON FUNCTION public.trigger_notification_outbox_worker() FROM PUBLIC;
    GRANT EXECUTE ON FUNCTION public.trigger_notification_outbox_worker() TO postgres, service_role;
  `;
  await runSQL(triggerFnSQL, 'CREATE TRIGGER FUNCTION');

  console.log('4. Updating pg_cron to use secure function with zero exposed secrets...');
  const cronUpdateSQL = `
    SELECT cron.unschedule(jobname) FROM cron.job WHERE jobname = 'cerelo-outbox-worker';
    
    SELECT cron.schedule(
      'cerelo-outbox-worker',
      '* * * * *',
      'SELECT public.trigger_notification_outbox_worker();'
    );
  `;
  await runSQL(cronUpdateSQL, 'UPDATE CRON JOB');

  console.log('5. Inspecting updated cron.job (verifying no secrets in command)...');
  await runSQL("SELECT jobid, jobname, schedule, active, command FROM cron.job WHERE jobname = 'cerelo-outbox-worker'", 'INSPECT CRON JOB');
}

main().catch(err => console.error(err));
