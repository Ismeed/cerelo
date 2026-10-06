import { redirect } from 'next/navigation'
import { getAdminSession } from '@/lib/auth/session'
import { Sidebar } from '@/components/layout/sidebar'

/**
 * Protected dashboard layout — wraps all /dashboard/* routes.
 *
 * SECURITY:
 * - getAdminSession() verifies admin role from server-issued JWT app_metadata.
 * - Unauthenticated or non-admin requests redirect to /login.
 * - This is the authoritative server-side authorization check for all
 *   dashboard routes. Middleware provides UX-level first-pass protection.
 */
export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const session = await getAdminSession()

  if (!session) {
    redirect('/login')
  }

  return (
    <div className="flex h-screen bg-surface overflow-hidden">
      <Sidebar adminRole={session.adminRole} />
      <main className="flex-1 overflow-auto">
        <div className="p-6 max-w-screen-xl">{children}</div>
      </main>
    </div>
  )
}
