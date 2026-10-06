'use client'

import { useEffect, useState, useCallback } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminOverviewMetrics } from '@/types/admin'
import Link from 'next/link'

export default function OverviewPage() {
  const [metrics, setMetrics] = useState<AdminOverviewMetrics | null>(null)
  const [loading, setLoading] = useState(true)
  const [hasError, setHasError] = useState(false)

  const loadMetrics = useCallback(async () => {
    setLoading(true)
    setHasError(false)
    const data = await adminService.getOverviewMetrics()
    if (data === null) {
      setHasError(true)
    } else {
      setMetrics(data)
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    loadMetrics()
  }, [loadMetrics])

  const formatNaira = (kobo: number) => {
    return `₦${(kobo / 100).toLocaleString('en-NG')}`
  }

  // A failed load must never be presented as a verified zero — every numeric
  // read below routes through this so the tile shows a neutral dash instead.
  const unavailable = loading || hasError

  return (
    <div className="space-y-8">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
            Operations Control Overview
          </h1>
          <p className="text-text-secondary text-sm">
            Live Kano ↔ Katsina corridor state and operational workload
          </p>
        </div>
        <button
          onClick={loadMetrics}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-cerelo-navy text-white text-xs font-bold hover:bg-slate-800 transition disabled:opacity-50"
        >
          <span>🔄</span>
          <span>{loading ? 'Refreshing...' : 'Refresh Metrics'}</span>
        </button>
      </div>

      {/* RPC Error State — shown when metrics cannot be loaded */}
      {hasError && !loading && (
        <div className="p-6 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-4">
          <div className="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 text-lg font-black">!</div>
          <div className="flex-1">
            <p className="text-sm font-bold text-amber-900">Unable to load operational metrics</p>
            <p className="text-xs text-amber-700 mt-0.5">
              The admin metrics query failed. This may indicate a database connectivity issue or a missing RPC.
              Check the Supabase Staging project and ensure <code className="font-mono">get_admin_overview_metrics</code> exists.
            </p>
          </div>
          <button
            onClick={loadMetrics}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-bold hover:bg-amber-700 transition"
          >
            Retry
          </button>
        </div>
      )}

      {/* Primary KPI Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-xl border border-border shadow-sm">
          <p className="text-xs font-bold text-text-tertiary uppercase tracking-wider">
            Awaiting Pickup
          </p>
          <p className="text-3xl font-black text-cerelo-navy mt-2">
            {unavailable ? '—' : metrics?.requests_awaiting_pickup ?? 0}
          </p>
          <p className="text-xs text-text-secondary mt-1">
            {unavailable ? '—' : metrics?.parcels_in_custody ?? 0} in personnel custody
          </p>
        </div>

        <div className="bg-white p-5 rounded-xl border border-border shadow-sm">
          <p className="text-xs font-bold text-text-tertiary uppercase tracking-wider">
            Middle-Mile Batches
          </p>
          <p className="text-3xl font-black text-cerelo-orange mt-2">
            {unavailable ? '—' : (metrics?.in_transit_batches ?? 0) + (metrics?.confirmed_batches ?? 0)}
          </p>
          <p className="text-xs text-text-secondary mt-1">
            {unavailable ? '—' : metrics?.in_transit_batches ?? 0} en route · {unavailable ? '—' : metrics?.confirmed_batches ?? 0} ready to depart
          </p>
        </div>

        <div className="bg-white p-5 rounded-xl border border-border shadow-sm">
          <p className="text-xs font-bold text-text-tertiary uppercase tracking-wider">
            Doorstep Deliveries
          </p>
          <p className="text-3xl font-black text-emerald-600 mt-2">
            {unavailable ? '—' : (metrics?.out_for_delivery ?? 0) + (metrics?.ready_for_delivery ?? 0)}
          </p>
          <p className="text-xs text-text-secondary mt-1">
            {unavailable ? '—' : metrics?.out_for_delivery ?? 0} out for delivery · {unavailable ? '—' : metrics?.delivered_today ?? 0} completed today
          </p>
        </div>

        <div className="bg-white p-5 rounded-xl border border-border shadow-sm">
          <p className="text-xs font-bold text-text-tertiary uppercase tracking-wider">
            Cash Collected Today
          </p>
          <p className="text-3xl font-black text-cerelo-navy mt-2">
            {unavailable ? '—' : formatNaira(metrics?.total_collected_today_kobo ?? 0)}
          </p>
          <p className="text-xs text-text-secondary mt-1">
            Physical cash collection total
          </p>
        </div>
      </div>

      {/* Corridor Direction Snapshot */}
      <div className="bg-white p-6 rounded-xl border border-border shadow-sm space-y-4">
        <h2 className="text-base font-bold text-cerelo-navy">
          Active Corridor Direction Snapshot
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="p-4 rounded-lg bg-surface-variant flex items-center justify-between">
            <div>
              <p className="text-sm font-bold text-text-primary">Kano Central Hub → Katsina Central Hub</p>
              <p className="text-xs text-text-secondary">Corridor KAN-KAT</p>
            </div>
            <span className="text-lg font-black text-cerelo-navy">
              {unavailable ? '—' : metrics?.kano_to_katsina_active_shipments ?? 0} Active
            </span>
          </div>

          <div className="p-4 rounded-lg bg-surface-variant flex items-center justify-between">
            <div>
              <p className="text-sm font-bold text-text-primary">Katsina Central Hub → Kano Central Hub</p>
              <p className="text-xs text-text-secondary">Corridor KAT-KAN</p>
            </div>
            <span className="text-lg font-black text-cerelo-navy">
              {unavailable ? '—' : metrics?.katsina_to_kano_active_shipments ?? 0} Active
            </span>
          </div>
        </div>
      </div>

      {/* Attention & Action Queue */}
      <div className="bg-white p-6 rounded-xl border border-border shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-bold text-cerelo-navy">
            Operational Attention Queue
          </h2>
          <Link
            href="/dashboard/incidents"
            className="text-xs font-bold text-cerelo-orange hover:underline"
          >
            View All Incidents ({unavailable ? '—' : metrics?.open_incidents ?? 0})
          </Link>
        </div>

        {unavailable ? (
          <div className="p-6 text-center text-amber-700 bg-amber-50 border border-amber-200 rounded-lg">
            <p className="text-sm font-semibold">Incident status unavailable — metrics failed to load.</p>
            <p className="text-xs text-amber-600 mt-1">This is not a report of zero incidents. Retry the metrics load above.</p>
          </div>
        ) : metrics?.open_incidents === 0 ? (
          <div className="p-6 text-center text-text-secondary bg-surface-variant/50 rounded-lg">
            <p className="text-sm font-semibold">No blocking operational incidents at this time.</p>
            <p className="text-xs text-text-tertiary mt-1">All pickups, transits, and deliveries moving normally.</p>
          </div>
        ) : (
          <div className="space-y-2">
            <div className="p-4 rounded-lg border border-amber-200 bg-amber-50 flex items-center justify-between">
              <div>
                <p className="text-sm font-bold text-amber-900">
                  {metrics?.open_incidents ?? 0} Open Operational Exception(s)
                </p>
                <p className="text-xs text-amber-700">
                  Missing parcels, receiver unreachable, or payment disputes requiring admin attention.
                </p>
              </div>
              <Link
                href="/dashboard/incidents"
                className="px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-bold hover:bg-amber-700 transition"
              >
                Inspect Issues
              </Link>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
