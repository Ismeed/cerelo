'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import { provisionPersonnelAction } from '@/lib/admin/admin-actions'
import type { AdminPersonnelSummary, OperatingHub } from '@/types/admin'

export default function PersonnelPage() {
  const [personnel, setPersonnel] = useState<AdminPersonnelSummary[]>([])
  const [hubs, setHubs] = useState<OperatingHub[]>([])
  const [loading, setLoading] = useState(true)
  const [hasError, setHasError] = useState(false)

  // Status toggle modal state
  const [selectedStaff, setSelectedStaff] = useState<AdminPersonnelSummary | null>(null)
  const [reason, setReason] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Provisioning modal state
  const [showProvisionModal, setShowProvisionModal] = useState(false)
  const [fullName, setFullName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [operatingHubId, setOperatingHubId] = useState('')
  const [isProvisioning, setIsProvisioning] = useState(false)

  // Feedback banner
  const [feedback, setFeedback] = useState<{ msg: string; isError: boolean } | null>(null)

  const loadData = async () => {
    setLoading(true)
    setHasError(false)
    const [personnelRes, hubsData] = await Promise.all([
      adminService.getPersonnelList(),
      adminService.getOperatingHubs(),
    ])
    if (personnelRes.error) {
      setHasError(true)
    } else {
      setPersonnel(personnelRes.data)
    }
    setHubs(hubsData)
    if (hubsData.length > 0 && !operatingHubId) {
      setOperatingHubId(hubsData[0].id)
    }
    setLoading(false)
  }

  useEffect(() => {
    loadData()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const handleToggleStatus = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedStaff || !reason.trim()) return

    setIsSubmitting(true)
    const newStatus = !selectedStaff.is_active
    const success = await adminService.setPersonnelStatus(
      selectedStaff.id,
      newStatus,
      reason.trim()
    )
    setIsSubmitting(false)

    if (success) {
      setFeedback({
        msg: `Staff member ${selectedStaff.full_name} ${newStatus ? 'reactivated' : 'suspended'} successfully.`,
        isError: false,
      })
      setSelectedStaff(null)
      setReason('')
      loadData()
    } else {
      setFeedback({
        msg: 'Failed to update personnel status. Please verify permissions.',
        isError: true,
      })
    }
  }

  const handleProvisionPersonnel = async (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!fullName.trim() || !email.trim() || !phone.trim() || !operatingHubId) {
      setFeedback({ msg: 'Please fill in all mandatory personnel details.', isError: true })
      return
    }

    setIsProvisioning(true)
    const res = await provisionPersonnelAction({
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phoneNumber: phone.trim(),
      operatingHubId,
    })
    setIsProvisioning(false)

    if (res.success && res.personnel) {
      setFeedback({
        msg: `Successfully provisioned ${fullName.trim()} (Staff ID: ${res.personnel.employeeReference}) for field operations.`,
        isError: false,
      })
      setShowProvisionModal(false)
      setFullName('')
      setEmail('')
      setPhone('')
      loadData()
    } else {
      setFeedback({
        msg: res.error || 'Failed to provision personnel.',
        isError: true,
      })
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
            Personnel & Field Operations Access
          </h1>
          <p className="text-text-secondary text-sm">
            Provision, manage hub scopes, and control field operational staff authorizations
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={loadData}
            disabled={loading}
            className="inline-flex items-center gap-2 px-3.5 py-2.5 bg-surface-variant hover:bg-border text-text-secondary hover:text-text-primary text-xs font-bold rounded-xl transition disabled:opacity-50"
          >
            <span>🔄</span>
            <span>{loading ? 'Refreshing...' : 'Refresh'}</span>
          </button>
          <button
            onClick={() => setShowProvisionModal(true)}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-cerelo-navy hover:bg-cerelo-navy/90 text-white text-sm font-bold rounded-xl shadow transition self-start sm:self-auto"
          >
            <span>＋</span>
            <span>Provision New Personnel</span>
          </button>
        </div>
      </div>

      {feedback && (
        <div
          className={`p-4 rounded-xl text-sm font-semibold border ${
            feedback.isError
              ? 'bg-red-50 text-red-700 border-red-200'
              : 'bg-emerald-50 text-emerald-700 border-emerald-200'
          }`}
        >
          {feedback.msg}
        </div>
      )}

      {/* RPC Error State — shown when the personnel query itself failed */}
      {hasError && !loading && (
        <div className="p-6 bg-amber-50 border border-amber-200 rounded-xl flex items-start gap-4">
          <div className="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center text-amber-700 text-lg font-black">!</div>
          <div className="flex-1">
            <p className="text-sm font-bold text-amber-900">Unable to load personnel</p>
            <p className="text-xs text-amber-700 mt-0.5">
              The personnel query failed. This is not the same as zero staff — check the Supabase Staging connection and retry.
            </p>
          </div>
          <button
            onClick={loadData}
            className="flex-shrink-0 px-3 py-1.5 rounded-lg bg-amber-600 text-white text-xs font-bold hover:bg-amber-700 transition"
          >
            Retry
          </button>
        </div>
      )}

      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-variant text-text-tertiary text-xs font-bold uppercase tracking-wider">
              <tr>
                <th className="p-4">Staff Member</th>
                <th className="p-4">Employee Ref</th>
                <th className="p-4">Phone Number</th>
                <th className="p-4">Home Hub Scope</th>
                <th className="p-4">Status</th>
                <th className="p-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    Loading personnel...
                  </td>
                </tr>
              ) : hasError ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-amber-700 font-semibold">
                    Could not load personnel — see error above.
                  </td>
                </tr>
              ) : personnel.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-8 text-center text-text-secondary">
                    No field personnel provisioned yet. Use &ldquo;Provision New Personnel&rdquo; to create field staff.
                  </td>
                </tr>
              ) : (
                personnel.map((p) => (
                  <tr key={p.id} className="hover:bg-surface-variant/30">
                    <td className="p-4 font-bold text-text-primary">{p.full_name}</td>
                    <td className="p-4 font-mono text-xs font-bold text-cerelo-navy">
                      {p.employee_reference}
                    </td>
                    <td className="p-4 text-text-secondary">{p.phone_number}</td>
                    <td className="p-4 font-medium text-text-secondary">
                      {p.operating_hub_name}
                    </td>
                    <td className="p-4">
                      <span
                        className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                          p.is_active
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-red-100 text-red-800'
                        }`}
                      >
                        {p.is_active ? 'ACTIVE' : 'SUSPENDED'}
                      </span>
                    </td>
                    <td className="p-4 text-right">
                      <button
                        onClick={() => setSelectedStaff(p)}
                        className={`px-3 py-1 text-xs font-bold rounded-lg border ${
                          p.is_active
                            ? 'border-red-300 text-red-600 hover:bg-red-50'
                            : 'border-emerald-300 text-emerald-600 hover:bg-emerald-50'
                        }`}
                      >
                        {p.is_active ? 'Suspend' : 'Reactivate'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Provision Personnel Modal */}
      {showProvisionModal && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-border space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <div>
                <h2 className="text-lg font-black text-cerelo-navy">
                  Provision New Field Personnel
                </h2>
                <p className="text-xs text-text-secondary mt-0.5">
                  Internal onboarding for physical parcel pickup, transit, and delivery staff.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setShowProvisionModal(false)}
                className="text-text-tertiary hover:text-text-primary text-xl font-bold"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleProvisionPersonnel} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1">
                  Full Name*
                </label>
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="e.g. Sani Aliyu"
                  className="w-full px-3 py-2 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-cerelo-navy"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1">
                    Internal Email (OTP Auth)*
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="pilot.kano@cerelonet.com"
                    className="w-full px-3 py-2 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-cerelo-navy"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1">
                    Phone Number*
                  </label>
                  <input
                    type="tel"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+2348000001001"
                    className="w-full px-3 py-2 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-cerelo-navy"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1">
                  Assigned Home Hub*
                </label>
                <select
                  required
                  value={operatingHubId}
                  onChange={(e) => setOperatingHubId(e.target.value)}
                  className="w-full px-3 py-2 border border-border rounded-xl text-sm font-medium focus:outline-none focus:border-cerelo-navy bg-white"
                >
                  {hubs.map((h) => (
                    <option key={h.id} value={h.id}>
                      {h.name} ({h.code})
                    </option>
                  ))}
                </select>
              </div>

              <div className="p-3 bg-surface-variant/70 rounded-xl text-xs text-text-secondary space-y-1">
                <div>
                  <span className="font-bold text-text-primary">Staff ID:</span> Will be auto-generated server-side sequentially per hub (e.g. <span className="font-mono font-bold text-cerelo-navy">CRL-KAN-0001</span>).
                </div>
                <div>
                  <span className="font-bold text-text-primary">Authentication:</span> Accounts are created without passwords. Staff authenticate exclusively via 6-digit Email OTP.
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowProvisionModal(false)}
                  className="px-4 py-2 border border-border rounded-xl text-sm font-semibold hover:bg-surface-variant"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isProvisioning}
                  className="px-5 py-2 bg-cerelo-navy hover:bg-cerelo-navy/90 text-white rounded-xl text-sm font-bold shadow disabled:opacity-50"
                >
                  {isProvisioning ? 'Provisioning Staff...' : 'Provision Staff Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Suspend / Reactivate Modal */}
      {selectedStaff && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-border space-y-4">
            <h2 className="text-lg font-black text-cerelo-navy">
              {selectedStaff.is_active ? 'Suspend Personnel Access' : 'Reactivate Personnel Access'}
            </h2>
            <p className="text-xs text-text-secondary">
              {selectedStaff.is_active
                ? `Suspending ${selectedStaff.full_name} immediately revokes all field operational capabilities (pickups, batch onboarding, delivery).`
                : `Reactivating ${selectedStaff.full_name} will restore their field operations access.`}
            </p>

            <form onSubmit={handleToggleStatus} className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-red-600 mb-1">
                  Reason for Status Change (Mandatory)*
                </label>
                <input
                  type="text"
                  required
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="e.g. Temporary leave / disciplinary review"
                  className="w-full p-2.5 border border-border rounded-xl text-sm"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => setSelectedStaff(null)}
                  className="px-4 py-2 border border-border rounded-xl text-sm font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting || !reason.trim()}
                  className={`px-4 py-2 text-white rounded-xl text-sm font-bold disabled:opacity-50 ${
                    selectedStaff.is_active ? 'bg-red-600 hover:bg-red-700' : 'bg-emerald-600 hover:bg-emerald-700'
                  }`}
                >
                  {isSubmitting
                    ? 'Updating...'
                    : selectedStaff.is_active
                    ? 'Confirm Suspension'
                    : 'Confirm Reactivation'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

