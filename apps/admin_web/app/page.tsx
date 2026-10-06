import { redirect } from 'next/navigation'

/**
 * Root page — redirects to dashboard overview.
 * Middleware handles redirect to /login if unauthenticated.
 */
export default function RootPage() {
  redirect('/dashboard/overview')
}
