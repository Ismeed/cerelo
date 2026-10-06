import { XCircle, ShieldCheck } from 'lucide-react';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { Badge } from '@/components/ui/Badge';
import type { PublicTrackingData } from '@/lib/types/tracking';

interface TrackingCancelledViewProps {
  data: PublicTrackingData;
}

export function TrackingCancelledView({ data }: TrackingCancelledViewProps) {
  return (
    <div className="bg-surface-white rounded-2xl border border-border p-6 sm:p-8 space-y-6 shadow-card">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
        <div className="space-y-1">
          <div className="flex items-center gap-2.5">
            <span className="font-mono text-base sm:text-lg font-bold text-cerelo-navy">
              {data.delivery_code}
            </span>
            <CorridorBadge
              from={data.origin_city}
              to={data.destination_city}
              size="sm"
            />
          </div>
          <p className="text-xs text-text-muted">
            Kano ↔ Katsina Corridor
          </p>
        </div>

        <Badge variant="error">Shipment Cancelled</Badge>
      </div>

      <div className="p-6 rounded-xl bg-surface-subtle border border-border space-y-3">
        <div className="flex items-start gap-3">
          <XCircle className="w-6 h-6 text-status-error shrink-0 mt-0.5" aria-hidden="true" />
          <div className="space-y-1">
            <h3 className="text-base font-bold text-cerelo-navy">Shipment Cancelled</h3>
            <p className="text-xs sm:text-sm text-text-secondary leading-relaxed">
              This shipment request was cancelled prior to corridor departure. No further delivery movements will occur.
            </p>
          </div>
        </div>
      </div>

      <div className="pt-4 border-t border-border flex items-center justify-between text-xs text-text-muted">
        <div className="flex items-center gap-1.5">
          <ShieldCheck className="w-4 h-4 text-status-success shrink-0" aria-hidden="true" />
          <span>Recorded in CERELO Immutable Operational Ledger</span>
        </div>
        <span>Kano ↔ Katsina Corridor</span>
      </div>
    </div>
  );
}
