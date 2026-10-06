'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminShipmentSummary } from '@/types/admin'

export default function ShipmentsPage() {
  const [shipments, setShipments] = useState<AdminShipmentSummary[]>([])
  const [loading, setLoading] = useState(true)
  const [hasError, setHasError] = useState(false)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('ALL')
  const [selectedShipment, setSelectedShipment] = useState<AdminShipmentSummary | null>(null)
  const [newPhone, setNewPhone] = useState('')
  const [newAddress, setNewAddress] = useState('')
  const [reason, setReason] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [feedback, setFeedback] = useState<{ msg: string; isError: boolean } | null>(null)

  const loadShipments = async () => {
    setLoading(true)
    setHasError(false)
    const { data, error } = await adminService.getShipmentsList({
      search,
      status: statusFilter,
    })
    if (error) {
      setHasError(true)
    } else {
      setShipments(data)
    }
    setLoading(false)
  }

  useEffect(() => {
    loadShipments()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter])

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    loadShipments()
  }

  const handleCorrectDetails = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedShipment || !reason.trim()) return

    setIsSubmitting(true)
    setFeedback(null)

    const success = await adminService.correctReceiverDetails(selectedShipment.id, {
      newPhone: newPhone.trim() || undefined,
      newAddress: newAddress.trim() || undefined,
      reason: reason.trim(),
    })

    setIsSubmitting(false)

    if (success) {
      setFeedback({ msg: 'Receiver details corrected and audited.', isError: false })
      setSelectedShipment(null)
      setNewPhone('')
      setNewAddress('')
      setReason('')
      loadShipments()
    } else {
      setFeedback({ msg: 'Failed to correct receiver details. Verify shipment status.', isError: true })
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
            Shipments Management
          </h1>
          <p className="text-text-secondary text-sm">
            Search, inspect, and perform audited receiver corrections
          </p>
        </div>
        <button
          onClick={loadShipments}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-cerelo-navy text-white text-xs font-bold hover:bg-slate-800 transition disabled:opacity-50"
        >
          <span>🔄</span>
          <span>{loading ? 'Refreshing...' : 'Refresh Shipments'}</span>
        </button>
      </div>

      {feedback && (
        <div
          className={`p-4 rounded-lg text-sm font-semibold ${
            feedback.isError
              ? 'bg-red-50 text-red-700 border border-red-200'
              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
          }`}
        >
          {feedback.msg}
        </div>
      )}

      {/* RPC Error State — shown when the shipments query itself failed */}
      {hasError && !loading && (
        <div className="p-6 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-4">
          <div className="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 text-lg font-black">!</div>
          <div className="flex-1">
            <p className="text-sm font-bold text-amber-900">Unable to load shipments</p>
            <p className="text-xs text-amber-700 mt-0.5">
              The shipments query failed. This is not the same as zero shipments — check the Supabase Staging connection and retry.
            </p>
          </div>
          <button
            onClick={loadShipments}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-bold hover:bg-amber-700 transition"
          >
            Retry
          </button>
        </div>
      )}

      {/* Filter and Search Bar */}
      <div className="bg-white p-4 rounded-xl border border-border shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <form onSubmit={handleSearchSubmit} className="flex items-center gap-2 w-full md:w-auto">
          <input
            type="text"
            placeholder="Search code, sender, receiver..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="px-3 py-2 border border-border rounded-lg text-sm w-full md:w-72 focus:outline-none focus:border-cerelo-navy"
          />
          <button
            type="submit"
            className="px-4 py-2 bg-cerelo-navy text-white rounded-lg text-sm font-bold hover:bg-cerelo-navy/90"
          >
            Search
          </button>
        </form>

        {/* Status Filter */}
        <div className="flex items-center gap-2 overflow-x-auto w-full md:w-auto">
          {['ALL', 'REQUESTED', 'PARCEL_CONFIRMED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED'].map(
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
                {st.replace('_', ' ')}
              </button>
            )
          )}
        </div>
      </div>

      {/* Shipments Table */}
      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-variant text-text-tertiary text-xs font-bold uppercase tracking-wider">
              <tr>
                <th className="p-4">Delivery Code</th>
                <th className="p-4">Route</th>
                <th className="p-4">Sender</th>
                <th className="p-4">Receiver</th>
                <th className="p-4">Status</th>
                <th className="p-4">Fee</th>
                <th className="p-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-text-secondary">
                    Loading shipments...
                  </td>
                </tr>
              ) : hasError ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-amber-700 font-semibold">
                    Could not load shipments — see error above.
                  </td>
                </tr>
              ) : shipments.length === 0 ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-text-secondary">
                    No shipments found matching criteria.
                  </td>
                </tr>
              ) : (
                shipments.map((s) => (
                  <tr key={s.id} className="hover:bg-surface-variant/30">
                    <td className="p-4 font-mono font-bold text-cerelo-navy">
                      {s.delivery_code ? (
                        s.delivery_code
                      ) : (
                        <span className="px-2 py-0.5 rounded text-xs font-bold bg-surface-variant text-text-tertiary">
                          PENDING
                        </span>
                      )}
                    </td>
                    <td className="p-4 font-medium">
                      {s.origin_city} → {s.destination_city}
                    </td>
                    <td className="p-4">
                      <p className="font-semibold text-text-primary">{s.sender_name}</p>
                      <p className="text-xs text-text-tertiary">{s.sender_phone}</p>
                    </td>
                    <td className="p-4">
                      <p className="font-semibold text-text-primary">{s.receiver_name}</p>
                      <p className="text-xs text-text-tertiary">{s.receiver_phone}</p>
                    </td>
                    <td className="p-4">
                      <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-cerelo-navy/10 text-cerelo-navy">
                        {s.current_status}
                      </span>
                    </td>
                    <td className="p-4">
                      <p className="font-bold text-text-primary">
                        ₦{(s.final_price_amount / 100).toLocaleString('en-NG')}
                      </p>
                      {s.quoted_price_amount > 0 &&
                        s.quoted_price_amount !== s.final_price_amount && (
                          <p className="text-xs text-cerelo-orange font-medium">
                            Quote: ₦{(s.quoted_price_amount / 100).toLocaleString('en-NG')}
                          </p>
                        )}
                      <p className="text-xs text-text-tertiary font-mono">
                        {s.payment_mode}
                      </p>
                    </td>
                    <td className="p-4 text-right">
                      {s.current_status !== 'DELIVERED' && (
                        <button
                          onClick={() => {
                            setSelectedShipment(s)
                            setNewPhone(s.receiver_phone)
                          }}
                          className="px-2.5 py-1 text-xs font-bold text-cerelo-orange hover:underline"
                        >
                          Correct Details
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Controlled Correction Modal */}
      {selectedShipment && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-xl max-w-lg w-full p-6 shadow-xl border border-border space-y-4">
            <h2 className="text-lg font-black text-cerelo-navy">
              Correct Receiver Details ({selectedShipment.delivery_code || 'PENDING'})
            </h2>
            <p className="text-xs text-text-secondary">
              Update recipient contact or address before final delivery. All changes generate an immutable audit log.
            </p>

            <form onSubmit={handleCorrectDetails} className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-text-secondary mb-1">
                  New Receiver Phone
                </label>
                <input
                  type="text"
                  value={newPhone}
                  onChange={(e) => setNewPhone(e.target.value)}
                  placeholder="e.g. +2348012345678"
                  className="w-full p-2.5 border border-border rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-text-secondary mb-1">
                  New Delivery Address
                </label>
                <textarea
                  value={newAddress}
                  onChange={(e) => setNewAddress(e.target.value)}
                  placeholder="Updated street address / landmark"
                  rows={2}
                  className="w-full p-2.5 border border-border rounded-lg text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-red-600 mb-1">
                  Operational Reason (Mandatory)*
                </label>
                <input
                  type="text"
                  required
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="e.g. Sender requested address correction via phone"
                  className="w-full p-2.5 border border-border rounded-lg text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setSelectedShipment(null)}
                  className="px-4 py-2 border border-border rounded-lg text-sm font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || !reason.trim()}
                  className="px-4 py-2 bg-cerelo-navy text-white rounded-lg text-sm font-bold disabled:opacity-50"
                >
                  {isSubmitting ? 'Saving...' : 'Save & Audit'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
