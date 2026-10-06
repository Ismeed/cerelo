'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminBatchSummary } from '@/types/admin'

export default function BatchesPage() {
  const [batches, setBatches] = useState<AdminBatchSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [hasError, setHasError] = useState(false)
  const [statusFilter, setStatusFilter] = useState('ALL')

  const loadBatches = async () => {
    setLoading(true)
    setHasError(false)
    const { data, error } = await adminService.getBatchesList()
    if (error) {
      setHasError(true)
    } else {
      setBatches(data)
    }
    setLoading(false)
  }

  useEffect(() => {
    loadBatches()
  }, [])

  const filteredBatches = batches.filter((b) => {
    if (statusFilter === 'ALL') return true
    if (statusFilter === 'IN_TRANSIT') return b.status === 'IN_TRANSIT' || b.status === 'ONBOARDED'
    if (statusFilter === 'RECEIVED_DESTINATION') return b.status === 'DESTINATION_RECEIVED' || b.status === 'RECEIVED_DESTINATION'
    return b.status === statusFilter
  })

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
            Middle-Mile Batches & Transit
          </h1>
          <p className="text-text-secondary text-sm">
            Monitor consolidated middle-mile batches, frozen manifests, and destination hub reconciliations
          </p>
        </div>
        <button
          onClick={loadBatches}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-cerelo-navy text-white text-xs font-bold hover:bg-slate-800 transition disabled:opacity-50"
        >
          <span>🔄</span>
          <span>{loading ? 'Refreshing...' : 'Refresh Batches'}</span>
        </button>
      </div>

      {/* Filter bar */}
      <div className="bg-white p-4 rounded-xl border border-border shadow-sm flex items-center justify-between gap-4">
        <div className="flex items-center gap-2 overflow-x-auto w-full">
          {['ALL', 'DRAFT', 'CONFIRMED', 'IN_TRANSIT', 'RECEIVED_DESTINATION', 'RECONCILED'].map(
            (st) => (
              <button
                key={st}
                onClick={() => setStatusFilter(st)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold whitespace-nowrap transition ${
                  statusFilter === st
                    ? 'bg-cerelo-navy text-white'
                    : 'bg-surface-variant text-text-secondary hover:bg-border'
                }`}
              >
                {st === 'IN_TRANSIT' ? 'IN TRANSIT' : st.replace(/_/g, ' ')}
              </button>
            )
          )}
        </div>
      </div>

      {/* RPC Error State — shown when the batches query itself failed */}
      {hasError && !loading && (
        <div className="p-6 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-4">
          <div className="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 text-lg font-black">!</div>
          <div className="flex-1">
            <p className="text-sm font-bold text-amber-900">Unable to load batches</p>
            <p className="text-xs text-amber-700 mt-0.5">
              The batches query failed. This is not the same as zero batches — check the Supabase Staging connection and retry.
            </p>
          </div>
          <button
            onClick={loadBatches}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-bold hover:bg-amber-700 transition"
          >
            Retry
          </button>
        </div>
      )}

      {/* Batches Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-variant text-text-tertiary text-xs font-bold uppercase tracking-wider">
              <tr>
                <th className="p-4">Batch Reference</th>
                <th className="p-4">Route Corridor</th>
                <th className="p-4">Batch Token / QR</th>
                <th className="p-4">Parcels in Manifest</th>
                <th className="p-4">Transit Status</th>
                <th className="p-4">Created</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    Loading batches...
                  </td>
                </tr>
              ) : hasError ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-amber-700 font-semibold">
                    Could not load batches — see error above.
                  </td>
                </tr>
              ) : filteredBatches.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    No batches found matching filter.
                  </td>
                </tr>
              ) : (
                filteredBatches.map((b) => (
                  <tr key={b.id} className="hover:bg-surface-variant/30">
                    <td className="p-4 font-mono font-bold text-cerelo-navy">
                      {b.batch_number}
                    </td>
                    <td className="p-4 font-medium">
                      {b.origin_hub_name} → {b.destination_hub_name}
                    </td>
                    <td className="p-4 font-mono text-xs text-text-secondary">
                      {b.batch_qr_token || '—'}
                    </td>
                    <td className="p-4 font-bold text-text-primary">
                      {b.manifest_count} {b.manifest_count === 1 ? 'parcel' : 'parcels'}
                    </td>
                    <td className="p-4">
                      <span
                        className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                          b.status === 'RECONCILED'
                            ? 'bg-emerald-100 text-emerald-800'
                            : b.status === 'IN_TRANSIT'
                            ? 'bg-blue-100 text-blue-800'
                            : b.status === 'CONFIRMED'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-surface-variant text-text-secondary'
                        }`}
                      >
                        {b.status}
                      </span>
                    </td>
                    <td className="p-4 text-xs text-text-tertiary">
                      {new Date(b.created_at).toLocaleDateString('en-NG', {
                        day: 'numeric',
                        month: 'short',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
