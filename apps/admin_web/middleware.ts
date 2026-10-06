import { createServerClient, type CookieOptions } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Next.js middleware for Admin route protection.
 *
 * SECURITY:
 * - All /dashboard/* routes require an authenticated admin session.
 * - Role is verified server-side from JWT app_metadata (server-controlled).
 * - This middleware is the first line of UX route protection.
 * - Server Components and Server Actions provide the authoritative second check.
 *
 * NOTE: Route guards here are UX only. The authoritative security boundary
 * is server-side authorization in each route and action handler.
 */
export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          )
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // Refresh session token if expired
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const isProtectedRoute = request.nextUrl.pathname.startsWith('/dashboard')
  const isLoginPage = request.nextUrl.pathname === '/login'

  // Redirect unauthenticated users to login
  if (!user && isProtectedRoute) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = '/login'
    loginUrl.searchParams.set('redirectTo', request.nextUrl.pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Verify admin role from server-issued JWT app_metadata
  if (user && isProtectedRoute) {
    const role = user.app_metadata?.role as string | undefined
    if (role !== 'admin') {
      const loginUrl = request.nextUrl.clone()
      loginUrl.pathname = '/login'
      loginUrl.searchParams.set('error', 'unauthorized')
      return NextResponse.redirect(loginUrl)
    }
  }

  // Redirect authenticated admins away from login
  if (user && isLoginPage && user.app_metadata?.role === 'admin') {
    const dashboardUrl = request.nextUrl.clone()
    dashboardUrl.pathname = '/dashboard/overview'
    return NextResponse.redirect(dashboardUrl)
  }

  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|public).*)'],
}
