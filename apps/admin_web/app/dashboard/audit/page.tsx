'use client'

import { useEffect, useState } from 'react'
import { adminService } from '@/lib/admin/admin-service'
import type { AdminAuditLog } from '@/types/admin'

export default function AuditPage() {
  const [logs, setLogs] = useState<AdminAuditLog[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminService.getAuditLogs().then((data) => {
      setLogs(data)
      setLoading(false)
    })
  }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-black text-cerelo-navy tracking-tight">
          Immutable System Audit Logs
        </h1>
        <p className="text-text-secondary text-sm">
          Read-only audit trail capturing all administrative corrections, role changes, and security events
        </p>
      </div>

      <div className="bg-white rounded-xl border border-border shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-surface-variant text-text-tertiary text-xs font-bold uppercase tracking-wider">
              <tr>
                <th className="p-4">Timestamp</th>
                <th className="p-4">Admin Actor</th>
                <th className="p-4">Action</th>
                <th className="p-4">Target Type</th>
                <th className="p-4">Reason / Notes</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-text-secondary">
                    Loading audit trail...
                  </td>
                </tr>
              ) : logs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-text-secondary">
                    No administrative audit events recorded yet.
                  </td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id} className="hover:bg-surface-variant/30">
                    <td className="p-4 text-xs font-mono text-text-tertiary whitespace-nowrap">
                      {new Date(log.created_at).toLocaleString()}
                    </td>
                    <td className="p-4 font-bold text-text-primary text-xs">
                      {log.actor_email}
                    </td>
                    <td className="p-4 font-mono text-xs font-semibold text-cerelo-navy">
                      {log.action}
                    </td>
                    <td className="p-4 font-mono text-xs text-text-secondary">
                      {log.aggregate_type}
                    </td>
                    <td className="p-4 text-text-primary text-xs max-w-sm">
                      {log.reason}
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
