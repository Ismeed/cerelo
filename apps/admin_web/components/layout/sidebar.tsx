'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import type { AdminRole } from '@/lib/auth/session'

interface SidebarProps {
  adminRole: AdminRole | null
}

const opsNavItems = [
  { href: '/dashboard/overview', label: 'Overview', icon: '◈' },
  { href: '/dashboard/shipments', label: 'Shipments', icon: '📦' },
  { href: '/dashboard/batches', label: 'Batches', icon: '🚚' },
  { href: '/dashboard/personnel', label: 'Personnel', icon: '👤' },
  { href: '/dashboard/incidents', label: 'Incidents', icon: '⚠️' },
]

const systemNavItems = [
  { href: '/dashboard/configuration', label: 'Configuration', icon: '⚙️' },
  { href: '/dashboard/audit', label: 'Audit Logs', icon: '📋' },
]

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function Sidebar({ adminRole }: SidebarProps) {
  const pathname = usePathname()

  const handleSignOut = async () => {
    const { createBrowserSupabaseClient } = await import('@/lib/supabase/browser')
    const supabase = createBrowserSupabaseClient()
    await supabase.auth.signOut()
    window.location.href = '/login'
  }

  return (
    <aside className="w-64 border-r border-border bg-white flex flex-col shrink-0 min-h-screen">
      {/* Brand header */}
      <div className="p-5 border-b border-border bg-cerelo-navy">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-cerelo-orange flex items-center justify-center shrink-0">
            <span className="text-white text-base font-black tracking-wider">C</span>
          </div>
          <div className="min-w-0">
            <p className="text-base font-black text-white tracking-wide">CERELO</p>
            <p className="text-xs text-white/70">Operations Admin</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
        <SectionLabel>Operations</SectionLabel>
        {opsNavItems.map((item) => {
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition-colors',
                isActive
                  ? 'bg-cerelo-navy text-white'
                  : 'text-text-secondary hover:bg-surface-variant hover:text-text-primary'
              )}
            >
              <span className="text-base">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          )
        })}

        <SectionLabel className="mt-6">System & Control</SectionLabel>
        {systemNavItems.map((item) => {
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-semibold transition-colors',
                isActive
                  ? 'bg-cerelo-navy text-white'
                  : 'text-text-secondary hover:bg-surface-variant hover:text-text-primary'
              )}
            >
              <span className="text-base">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          )
        })}
      </nav>

      {/* User Actions & Sign Out */}
      <div className="p-3 border-t border-border">
        <button
          onClick={handleSignOut}
          className="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg text-xs font-bold text-red-600 hover:bg-red-50 transition border border-red-200"
        >
          <span>🚪</span>
          <span>Sign Out</span>
        </button>
      </div>

      {/* Footer */}
      <div className="p-3 border-t border-border bg-surface-variant/50">
        <p className="text-[10px] font-semibold text-text-secondary text-center">
          Cerelo V1 · Kano ↔ Katsina Corridor
        </p>
      </div>
    </aside>
  )
}

function SectionLabel({
  children,
  className,
}: {
  children: React.ReactNode
  className?: string
}) {
  return (
    <p
      className={cn(
        'text-xs font-bold text-text-tertiary uppercase tracking-wider px-3 py-2',
        className
      )}
    >
      {children}
    </p>
  )
}
