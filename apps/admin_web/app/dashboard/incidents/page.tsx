'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminIncidentSummary } from '@/types/admin'

export default function IncidentsPage() {
  const [incidents, setIncidents] = useState<AdminIncidentSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [statusFilter, setStatusFilter] = useState('ALL')
  const [selectedIncident, setSelectedIncident] = useState<AdminIncidentSummary | null>(null)
  const [resolutionNotes, setResolutionNotes] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)

  const loadIncidents = async () => {
    setLoading(true)
    const data = await adminService.getIncidentsList(statusFilter)
    setIncidents(data)
    setLoading(false)
  }

  useEffect(() => {
    loadIncidents()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter])

  const handleResolve = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedIncident || !resolutionNotes.trim()) return

    setIsSubmitting(true)
    const success = await adminService.resolveIncident(
      selectedIncident.id,
      resolutionNotes.trim()
    )
    setIsSubmitting(false)

    if (success) {
      setFeedback('Incident resolved successfully and audit log updated.')
      setSelectedIncident(null)
      setResolutionNotes('')
      loadIncidents()
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
            Operational Incidents & Exceptions
          </h1>
          <p className="text-text-secondary text-sm">
            Inspect operational discrepancies, missing items, and resolve blocking delivery issues
          </p>
        </div>

        {/* Filter */}
        <div className="flex items-center gap-2">
          {['ALL', 'OPEN', 'RESOLVED'].map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                statusFilter === st
                  ? 'bg-cerelo-navy text-white'
                  : 'bg-surface-variant text-text-secondary hover:bg-border'
              }`}
            >
              {st}
            </button>
          ))}
        </div>
      </div>

      {feedback && (
        <div className="p-4 rounded-lg bg-emerald-50 text-emerald-700 border border-emerald-200 text-sm font-semibold">
          {feedback}
        </div>
      )}

      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-variant text-text-tertiary text-xs font-bold uppercase tracking-wider">
              <tr>
                <th className="p-4">Resource</th>
                <th className="p-4">Category</th>
                <th className="p-4">Notes</th>
                <th className="p-4">Status</th>
                <th className="p-4">Date</th>
                <th className="p-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    Loading incidents...
                  </td>
                </tr>
              ) : incidents.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    No incidents recorded matching filter.
                  </td>
                </tr>
              ) : (
                incidents.map((inc) => (
                  <tr key={inc.id} className="hover:bg-surface-variant/30">
                    <td className="p-4 font-mono text-xs font-bold text-cerelo-navy">
                      {inc.resource_type}
                    </td>
                    <td className="p-4 font-semibold text-text-primary">
                      {inc.category}
                    </td>
                    <td className="p-4 text-text-secondary text-xs max-w-xs truncate">
                      {inc.notes || '—'}
                    </td>
                    <td className="p-4">
                      <span
                        className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                          inc.status === 'OPEN'
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-emerald-100 text-emerald-800'
                        }`}
                      >
                        {inc.status}
                      </span>
                    </td>
                    <td className="p-4 text-xs text-text-tertiary">
                      {new Date(inc.created_at).toLocaleDateString()}
                    </td>
                    <td className="p-4 text-right">
                      {inc.status === 'OPEN' ? (
                        <button
                          onClick={() => setSelectedIncident(inc)}
                          className="px-3 py-1 text-xs font-bold text-cerelo-orange hover:underline"
                        >
                          Resolve Issue
                        </button>
                      ) : (
                        <span className="text-xs text-text-tertiary">Resolved</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Resolution Modal */}
      {selectedIncident && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-xl border border-border space-y-4">
            <h2 className="text-lg font-black text-cerelo-navy">
              Resolve Operational Incident
            </h2>
            <p className="text-xs text-text-secondary">
              Category: <span className="font-bold text-text-primary">{selectedIncident.category}</span>
            </p>
            <p className="text-xs text-text-secondary bg-surface-variant p-3 rounded-lg">
              Original notes: {selectedIncident.notes || 'No description provided.'}
            </p>

            <form onSubmit={handleResolve} className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-text-secondary mb-1">
                  Resolution Notes (Mandatory)*
                </label>
                <textarea
                  required
                  rows={3}
                  value={resolutionNotes}
                  onChange={(e) => setResolutionNotes(e.target.value)}
                  placeholder="Explain how this discrepancy was verified, resolved, or approved for delivery."
                  className="w-full p-2.5 border border-border rounded-lg text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setSelectedIncident(null)}
                  className="px-4 py-2 border border-border rounded-lg text-sm font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || !resolutionNotes.trim()}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-sm font-bold disabled:opacity-50"
                >
                  {isSubmitting ? 'Resolving...' : 'Confirm Resolution'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
