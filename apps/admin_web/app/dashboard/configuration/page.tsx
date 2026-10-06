'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminConfiguration } from '@/types/admin'

export default function ConfigurationPage() {
  const [config, setConfig] = useState<AdminConfiguration | null>(null)
  const [loading, setLoading] = useState(true)
  const [feedback, setFeedback] = useState<string | null>(null)

  const loadConfig = async () => {
    setLoading(true)
    const data = await adminService.getConfiguration()
    setConfig(data)
    setLoading(false)
  }

  useEffect(() => {
    loadConfig()
  }, [])

  const handleToggleCorridor = async (corridorId: string, currentActive: boolean) => {
    const reason = prompt(
      `Enter operational reason to ${currentActive ? 'deactivate' : 'activate'} this corridor:`
    )
    if (!reason?.trim()) return

    const success = await adminService.toggleCorridorActive(
      corridorId,
      !currentActive,
      reason.trim()
    )

    if (success) {
      setFeedback('Corridor activation state updated and audited.')
      loadConfig()
    }
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
          Business & Operational Configuration
        </h1>
        <p className="text-text-secondary text-sm">
          Manage live intercity corridors, parcel size tiers, and base pricing rules
        </p>
      </div>

      {feedback && (
        <div className="p-4 rounded-lg bg-emerald-50 text-emerald-700 border border-emerald-200 text-sm font-semibold">
          {feedback}
        </div>
      )}

      {/* Corridors Section */}
      <div className="bg-white p-6 rounded-xl border border-border shadow-sm space-y-4">
        <h2 className="text-base font-bold text-cerelo-navy">
          Active Directional Corridors (V1)
        </h2>
        <p className="text-xs text-text-secondary">
          Deactivating a corridor immediately stops new shipment requests on that route while in-transit deliveries complete normally.
        </p>

        <div className="divide-y divide-border border border-border rounded-lg overflow-hidden">
          {loading ? (
            <div className="p-4 text-center text-text-secondary text-sm">Loading corridors...</div>
          ) : config?.corridors.length === 0 ? (
            <div className="p-4 text-center text-text-secondary text-sm">No corridors configured.</div>
          ) : (
            config?.corridors.map((c) => (
              <div key={c.id} className="p-4 flex items-center justify-between hover:bg-surface-variant/30">
                <div>
                  <p className="text-sm font-bold text-text-primary">
                    {c.origin_city} → {c.destination_city}
                  </p>
                  <p className="text-xs text-text-secondary">
                    Code: <span className="font-mono">{c.code}</span> · {c.name}
                  </p>
                </div>

                <div className="flex items-center gap-3">
                  <span
                    className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                      c.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'
                    }`}
                  >
                    {c.is_active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                  <button
                    onClick={() => handleToggleCorridor(c.id, c.is_active)}
                    className="px-3 py-1 border border-border rounded-lg text-xs font-bold hover:bg-surface-variant"
                  >
                    {c.is_active ? 'Deactivate' : 'Activate'}
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Parcel Size Tiers & Base Pricing */}
      <div className="bg-white p-6 rounded-xl border border-border shadow-sm space-y-4">
        <h2 className="text-base font-bold text-cerelo-navy">
          Parcel Size Tiers & Base Pricing
        </h2>
        <p className="text-xs text-text-secondary">
          Configured size boundaries and baseline pricing per tier for Kano ↔ Katsina shipments.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="p-4 rounded-xl border border-border bg-surface-variant/30 space-y-2">
            <span className="px-2 py-0.5 rounded text-xs font-bold bg-blue-100 text-blue-800">
              SMALL
            </span>
            <p className="text-sm font-bold text-text-primary">Small Package</p>
            <p className="text-xs text-text-secondary">
              Documents, small accessories, lightweight electronics.
            </p>
            <p className="text-lg font-black text-cerelo-navy pt-2">₦2,000</p>
          </div>

          <div className="p-4 rounded-xl border border-border bg-surface-variant/30 space-y-2">
            <span className="px-2 py-0.5 rounded text-xs font-bold bg-amber-100 text-amber-800">
              MEDIUM
            </span>
            <p className="text-sm font-bold text-text-primary">Medium Package</p>
            <p className="text-xs text-text-secondary">
              Fabric bundles, shoe boxes, fashion items, electronic accessories.
            </p>
            <p className="text-lg font-black text-cerelo-navy pt-2">₦3,500</p>
          </div>

          <div className="p-4 rounded-xl border border-border bg-surface-variant/30 space-y-2">
            <span className="px-2 py-0.5 rounded text-xs font-bold bg-purple-100 text-purple-800">
              LARGE
            </span>
            <p className="text-sm font-bold text-text-primary">Large Package</p>
            <p className="text-xs text-text-secondary">
              Heavy bales of textile, bulky merchant orders, large equipment.
            </p>
            <p className="text-lg font-black text-cerelo-navy pt-2">₦6,000</p>
          </div>
        </div>
      </div>
    </div>
  )
}
