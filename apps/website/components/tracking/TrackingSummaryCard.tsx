import { Badge } from '@/components/ui/Badge';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { getStatusDisplay, formatMilestoneTime } from '@/lib/data/status-mapping';
import type { PublicTrackingData } from '@/lib/types/tracking';
import { Clock, ShieldCheck, MapPin } from 'lucide-react';

interface TrackingSummaryCardProps {
  data: PublicTrackingData;
}

export function TrackingSummaryCard({ data }: TrackingSummaryCardProps) {
  const statusInfo = getStatusDisplay(data.current_status);
  const latestMilestone = data.milestones.length > 0
    ? data.milestones[data.milestones.length - 1]
    : null;

  return (
    <div className="bg-surface-white rounded-2xl border border-border p-6 sm:p-8 space-y-6 shadow-card">
      {/* ── Top Header Row: Delivery Code + Corridor + Status Badge ── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
        <div className="space-y-1.5">
          <div className="flex flex-wrap items-center gap-2.5">
            <span className="font-mono text-base sm:text-lg font-bold text-cerelo-navy tracking-wider">
              {data.delivery_code || 'CERELO Shipment'}
            </span>
            <CorridorBadge
              from={data.origin_city}
              to={data.destination_city}
              size="sm"
            />
          </div>

          <div className="flex items-center gap-1.5 text-xs text-text-secondary">
            <MapPin className="w-3.5 h-3.5 text-cerelo-orange shrink-0" aria-hidden="true" />
            <span>Intercity Door-to-Door Corridor Delivery</span>
          </div>
        </div>

        <Badge variant={statusInfo.badgeVariant} className="self-start sm:self-center">
          {statusInfo.customerLabel}
        </Badge>
      </div>

      {/* ── Current Status Headline & Explanation ──────────────────── */}
      <div className="space-y-2">
        <h2 className="text-xl sm:text-2xl font-bold text-cerelo-navy">
          {statusInfo.customerLabel}
        </h2>
        <p className="text-sm text-text-secondary leading-relaxed max-w-2xl">
          {statusInfo.description}
        </p>
      </div>

      {/* ── Bottom Ledger Verification Footer ──────────────────────── */}
      <div className="pt-4 border-t border-border flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs text-text-muted">
        <div className="flex items-center gap-1.5">
          <ShieldCheck className="w-4 h-4 text-status-success shrink-0" aria-hidden="true" />
          <span>Verified in CERELO Operational Event Ledger</span>
        </div>

        {latestMilestone && (
          <div className="flex items-center gap-1.5">
            <Clock className="w-3.5 h-3.5 text-text-muted shrink-0" aria-hidden="true" />
            <span>Updated: {formatMilestoneTime(latestMilestone.created_at)}</span>
          </div>
        )}
      </div>
    </div>
  );
}
