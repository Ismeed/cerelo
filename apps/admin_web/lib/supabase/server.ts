import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { cookies } from 'next/headers'

/**
 * Creates a Supabase client for use in Server Components and Server Actions.
 *
 * SECURITY:
 * - Uses httpOnly cookies for session management (XSS-safe).
 * - Never expose the service role key in this file.
 * - Row Level Security (RLS) enforces data access at the database layer.
 * - Admin role is verified from JWT app_metadata (server-controlled).
 */
export async function createServerSupabaseClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Server Component — cannot set cookies during render
          }
        },
      },
    }
  )
}
