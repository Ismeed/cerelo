/**
 * CORS configuration for Cerelo Edge Functions.
 *
 * SECURITY:
 * - Allowed origins are explicitly listed — no wildcard (*) for authenticated endpoints.
 * - Production origin is injected via ALLOWED_ORIGIN environment variable,
 *   never hard-coded in source.
 * - Development allows localhost for local testing only.
 */

const allowedOrigins = [
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  Deno.env.get('ALLOWED_ORIGIN') ?? '',
].filter(Boolean)

export function getCorsHeaders(requestOrigin: string | null): HeadersInit {
  const isAllowed = requestOrigin !== null && allowedOrigins.includes(requestOrigin)
  const origin = isAllowed ? requestOrigin! : (allowedOrigins[0] ?? 'http://localhost:3000')

  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type, x-idempotency-key',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Max-Age': '86400',
  }
}

/** Returns a CORS preflight response if the request method is OPTIONS. */
export function handleOptions(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    const origin = req.headers.get('origin')
    return new Response(null, { headers: getCorsHeaders(origin) })
  }
  return null
}
