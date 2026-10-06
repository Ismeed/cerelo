import { handleOptions, getCorsHeaders } from '../_shared/cors.ts'
import { resolveSupabaseSecretKey, createServiceRoleClient } from '../_shared/auth.ts'
import { CERELO_STAGING_SECRET_KEY_NAME } from '../_shared/secret_key_config.ts'

/**
 * Cerelo Health Check & Credential Probe Edge Function
 *
 * Confirms the Edge Function runtime is operational and provides safe,
 * non-secret verification of the hosted credential integration.
 *
 * SECURITY: Does NOT expose:
 *   - Database connection details or credentials
 *   - Service role keys, new API keys, or internal secrets
 *   - Infrastructure topology
 *   - Secret dictionary contents
 *
 * Endpoint: GET /functions/v1/health
 * Optional query parameter: ?probe=1 (runs non-secret hosted credential probe)
 */
Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  const preflightResponse = handleOptions(req)
  if (preflightResponse) return preflightResponse

  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

  if (req.method !== 'GET' && req.method !== 'POST') {
    return new Response(
      JSON.stringify({ code: 'METHOD_NOT_ALLOWED', message: 'Use GET or POST.' }),
      {
        status: 405,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      }
    )
  }

  const url = new URL(req.url)
  const isProbeRequested = url.searchParams.get('probe') === '1' || url.searchParams.get('diagnostic') === '1'

  const baseResponse: Record<string, unknown> = {
    status: 'ok',
    service: 'cerelo-edge-functions',
    version: '0.1.0',
    environment: Deno.env.get('APP_ENV') ?? 'development',
    timestamp: new Date().toISOString(),
  }

  if (isProbeRequested) {
    const rawSecretKeys = Deno.env.get('SUPABASE_SECRET_KEYS')
    let jsonParseOk = false
    let configuredKeyFound = false
    let totalKeysFound = 0

    if (rawSecretKeys) {
      try {
        const parsed = JSON.parse(rawSecretKeys)
        jsonParseOk = true
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          totalKeysFound = Object.keys(parsed).length
          configuredKeyFound = Boolean(
            CERELO_STAGING_SECRET_KEY_NAME && parsed[CERELO_STAGING_SECRET_KEY_NAME]
          )
        } else if (Array.isArray(parsed)) {
          totalKeysFound = parsed.length
          configuredKeyFound = Boolean(
            parsed.find(
              (item) =>
                item &&
                (item.name === CERELO_STAGING_SECRET_KEY_NAME ||
                  item.id === CERELO_STAGING_SECRET_KEY_NAME)
            )
          )
        }
      } catch (_e) {
        jsonParseOk = false
      }
    }

    let credentialSource = 'NONE'
    let keyTypeValid = false
    let readOnlyQueryOk = false
    let hubsCount = 0

    try {
      const resolved = resolveSupabaseSecretKey()
      credentialSource = resolved.source
      keyTypeValid = typeof resolved.key === 'string' && (
        resolved.key.startsWith('sb_secret_') ||
        resolved.key.startsWith('eyJ') ||
        resolved.key.length > 20
      )

      // Perform harmless read-only test using the resolved secret client
      const adminClient = createServiceRoleClient()
      const { data: hubs, error: hubsErr } = await adminClient
        .from('operating_hubs')
        .select('id')
        .limit(5)

      if (!hubsErr && hubs) {
        readOnlyQueryOk = true
        hubsCount = hubs.length
      }
    } catch (_e) {
      readOnlyQueryOk = false
    }

    baseResponse.credential_probe = {
      supabase_secret_keys_present: Boolean(rawSecretKeys),
      json_parse_ok: jsonParseOk,
      total_keys_in_dictionary: totalKeysFound,
      configured_key_name: CERELO_STAGING_SECRET_KEY_NAME,
      configured_key_found: configuredKeyFound,
      selected_credential_source: credentialSource,
      key_type_valid: keyTypeValid,
      legacy_service_role_fallback_present: Boolean(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')),
      worker_secret_key_present: Boolean(Deno.env.get('WORKER_SECRET_KEY')),
      worker_secret_key_length: Deno.env.get('WORKER_SECRET_KEY')?.length ?? 0,
      read_only_staging_query_ok: readOnlyQueryOk,
      hubs_count: hubsCount,
    }
  }

  return new Response(JSON.stringify(baseResponse), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache',
      ...corsHeaders,
    },
  })
})
