// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { CERELO_STAGING_SECRET_KEY_NAME } from './secret_key_config.ts'

/**
 * Shared authentication helper for Cerelo Edge Functions.
 *
 * SECURITY PRINCIPLES ENFORCED HERE:
 *   - Identity is derived from Authorization header JWT — never from request body.
 *   - Role is read from app_metadata (server-controlled), not user_metadata (client-settable).
 *   - Service role key operations are isolated in server-only context.
 *   - Actor identity is never trusted from client-sent fields.
 *   - Secret values or SUPABASE_SECRET_KEYS dictionaries are NEVER logged or echoed.
 *   - Legacy SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY fallbacks are ERADICATED.
 *
 * Every protected Edge Function must call getAuthenticatedActor() or requireRole()
 * as the first operation before processing any business logic.
 */

export type CereloRole = 'customer' | 'personnel' | 'admin' | 'system'

export interface AuthenticatedActor {
  userId: string
  email: string | undefined
  role: CereloRole
  /** Hub city assigned to this Personnel (e.g., 'kano' | 'katsina'). */
  hubCity?: string
  /** Admin sub-role ('SUPER_ADMIN' | 'OPS_MANAGER' | 'SUPPORT'). */
  adminRole?: string
}

/**
 * Resolves the client-safe Supabase publishable key in Edge Function environment.
 *
 * CREDENTIAL RESOLUTION ORDER:
 * 1. Supabase-provided SUPABASE_PUBLISHABLE_KEYS JSON dictionary (built-in to Edge Functions)
 * 2. Direct SUPABASE_PUBLISHABLE_KEY (local/dev)
 *
 * SECURITY:
 * - Legacy SUPABASE_ANON_KEY fallback is completely eradicated.
 * - Never returns secret keys or service role keys.
 */
export function resolveSupabasePublishableKey(): string {
  const pubKeysJson = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')
  if (pubKeysJson) {
    try {
      const parsed = JSON.parse(pubKeysJson)
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        const values = Object.values(parsed)
        if (values.length > 0 && typeof values[0] === 'string' && values[0]) {
          return values[0] as string
        }
      }
      if (Array.isArray(parsed) && parsed.length > 0) {
        const val = parsed[0]?.publishable || parsed[0]?.key || parsed[0]?.secret || parsed[0]?.value
        if (typeof val === 'string' && val) return val
      }
    } catch (_err) {
      // JSON parse error — continue to direct env check
    }
  }

  const direct = Deno.env.get('SUPABASE_PUBLISHABLE_KEY')
  if (direct) return direct

  throw new Error('No valid Supabase publishable key found in Edge Function environment.')
}

/**
 * Extracts and verifies the authenticated actor from the request JWT.
 *
 * @returns AuthenticatedActor if valid JWT present, null otherwise.
 */
export async function getAuthenticatedActor(
  req: Request
): Promise<AuthenticatedActor | null> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return null
  }

  const jwt = authHeader.replace('Bearer ', '').trim()
  if (!jwt) return null

  // Use publishable client with the user's JWT to verify identity server-side.
  const pubKey = resolveSupabasePublishableKey()
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    pubKey,
    { global: { headers: { Authorization: `Bearer ${jwt}` } } }
  )

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()

  if (error || !user) return null

  // SECURITY: Role from app_metadata (server-set), NEVER user_metadata.
  const role = ((user.app_metadata as any)?.role ?? 'customer') as CereloRole
  const hubCity = (user.app_metadata as any)?.hub_city as string | undefined
  const adminRole = (user.app_metadata as any)?.admin_role as string | undefined

  return { userId: user.id, email: user.email, role, hubCity, adminRole }
}

/**
 * Requires the calling actor to have a specific role.
 * Returns the actor on success, or a structured error Response on failure.
 *
 * Usage pattern in Edge Functions:
 *   const actorOrError = await requireRole(req, 'personnel')
 *   if (actorOrError instanceof Response) return actorOrError
 *   // actorOrError is now AuthenticatedActor
 */
export async function requireRole(
  req: Request,
  requiredRole: CereloRole
): Promise<AuthenticatedActor | Response> {
  const actor = await getAuthenticatedActor(req)

  if (!actor) {
    return new Response(
      JSON.stringify({ code: 'UNAUTHENTICATED', message: 'Authentication required.' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } }
    )
  }

  if (actor.role !== requiredRole) {
    return new Response(
      JSON.stringify({
        code: 'FORBIDDEN',
        message: 'You do not have permission to perform this action.',
      }),
      { status: 403, headers: { 'Content-Type': 'application/json' } }
    )
  }

  return actor
}

export interface ResolvedSecretKey {
  key: string
  source: string
  keyName?: string
}

/**
 * Resolves the server-side Supabase secret key in Edge Function environment.
 *
 * CREDENTIAL RESOLUTION ORDER:
 * 1. Supabase-provided SUPABASE_SECRET_KEYS JSON dictionary (built-in to Edge Functions):
 *    - Looks up exact configured key: CERELO_STAGING_SECRET_KEY_NAME ('cerelo_staging_backend_2026_08')
 *    - If not matched, selects first available named key in the dictionary
 * 2. Direct SUPABASE_SECRET_KEY (for local development/testing)
 *
 * SECURITY:
 * - Legacy SUPABASE_SERVICE_ROLE_KEY fallback is completely ERADICATED.
 * - NEVER logs or exposes the JSON dictionary, individual secret values, or digests.
 */
export function resolveSupabaseSecretKey(): ResolvedSecretKey {
  const secretKeysJson = Deno.env.get('SUPABASE_SECRET_KEYS')

  if (secretKeysJson) {
    try {
      const parsed = JSON.parse(secretKeysJson)

      // Format A: Dictionary { "key-name": "sb_secret_..." }
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        if (
          CERELO_STAGING_SECRET_KEY_NAME &&
          typeof parsed[CERELO_STAGING_SECRET_KEY_NAME] === 'string' &&
          parsed[CERELO_STAGING_SECRET_KEY_NAME]
        ) {
          return {
            key: parsed[CERELO_STAGING_SECRET_KEY_NAME],
            source: `SECRET_KEYS/${CERELO_STAGING_SECRET_KEY_NAME}`,
            keyName: CERELO_STAGING_SECRET_KEY_NAME,
          }
        }

        const keys = Object.keys(parsed)
        if (keys.length > 0) {
          const firstKey = keys[0]
          if (typeof parsed[firstKey] === 'string' && parsed[firstKey]) {
            return {
              key: parsed[firstKey],
              source: `SECRET_KEYS/${firstKey}`,
              keyName: firstKey,
            }
          }
        }
      }

      // Format B: Array [ { name: "...", secret: "..." } ]
      if (Array.isArray(parsed)) {
        const found = parsed.find(
          (item) =>
            item &&
            (item.name === CERELO_STAGING_SECRET_KEY_NAME ||
              item.id === CERELO_STAGING_SECRET_KEY_NAME)
        )
        if (found) {
          const val = found.secret || found.value || found.key
          if (typeof val === 'string' && val) {
            return {
              key: val,
              source: `SECRET_KEYS/${CERELO_STAGING_SECRET_KEY_NAME}`,
              keyName: CERELO_STAGING_SECRET_KEY_NAME,
            }
          }
        }

        if (parsed.length > 0 && parsed[0]) {
          const first = parsed[0]
          const val = first.secret || first.value || first.key
          const name = first.name || first.id || 'default'
          if (typeof val === 'string' && val) {
            return {
              key: val,
              source: `SECRET_KEYS/${name}`,
              keyName: name,
            }
          }
        }
      }
    } catch (_err) {
      // JSON parse error — continue to direct secret check
    }
  }

  // Direct SUPABASE_SECRET_KEY (local/dev)
  const directSecret = Deno.env.get('SUPABASE_SECRET_KEY')
  if (directSecret) {
    return {
      key: directSecret,
      source: 'ENV/SUPABASE_SECRET_KEY',
    }
  }

  throw new Error(
    'No valid Supabase secret key found in Edge Function environment. ' +
      'SUPABASE_SECRET_KEYS dictionary or SUPABASE_SECRET_KEY is required.'
  )
}

/**
 * Creates a privileged Supabase admin client using the resolved secret key.
 *
 * SECURITY:
 * - ONLY use inside Deno Edge Functions (server-trusted environment).
 * - NEVER expose this client or its key to any client application.
 * - NEVER send the service key in any HTTP response.
 * - All operations with this client bypass RLS — use only when necessary.
 */
export function createServiceRoleClient() {
  const { key: serviceKey } = resolveSupabaseSecretKey()

  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    serviceKey,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    }
  )
}
