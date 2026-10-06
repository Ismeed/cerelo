import { createServerSupabaseClient } from '@/lib/supabase/server'

/**
 * Actor roles matching the cerelo_core ActorRole enum.
 */
export type CereloRole = 'customer' | 'personnel' | 'admin' | 'system'

/**
 * Admin sub-roles from JWT app_metadata.
 */
export type AdminRole = 'SUPER_ADMIN' | 'OPS_MANAGER' | 'SUPPORT'

/**
 * Represents the authenticated admin user.
 */
export interface AdminSession {
  userId: string
  email: string | undefined
  role: CereloRole
  adminRole: AdminRole | null
}

/**
 * Retrieves and validates the current admin session.
 *
 * SECURITY:
 * - Role is derived from app_metadata (server-controlled JWT claim).
 * - Never trusts user_metadata (client-settable) for authorization.
 * - Called in middleware and server-side layouts to protect admin routes.
 *
 * @returns AdminSession if authenticated admin, null otherwise.
 */
export async function getAdminSession(): Promise<AdminSession | null> {
  const supabase = await createServerSupabaseClient()
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser()

  if (error || !user) return null

  // SECURITY: Role comes from app_metadata (server-set), not user_metadata.
  const role = (user.app_metadata?.role as CereloRole) ?? 'customer'
  const adminRole = (user.app_metadata?.admin_role as AdminRole) ?? null

  // Only admin-role users may access the admin panel.
  if (role !== 'admin') return null

  return {
    userId: user.id,
    email: user.email,
    role,
    adminRole,
  }
}

/**
 * Verifies admin session in a Server Action context.
 * Throws if the caller is not an authenticated admin.
 */
export async function requireAdminSession(): Promise<AdminSession> {
  const session = await getAdminSession()
  if (!session) {
    throw new Error('UNAUTHENTICATED: Admin session required')
  }
  return session
}
