import { CheckCircle2, Clock, Circle } from 'lucide-react';
import { LIFECYCLE_STAGES } from '@/lib/data/stages';
import { getStatusDisplay, formatMilestoneTime } from '@/lib/data/status-mapping';
import type { PublicTrackingData, PublicMilestone } from '@/lib/types/tracking';
import { cn } from '@/lib/utils';

interface TrackingTimelineViewProps {
  data: PublicTrackingData;
}

/** Helper to match a lifecycle stage with its verified ledger milestone event */
function findMilestoneForStage(stageKey: string, milestones: PublicMilestone[]): PublicMilestone | undefined {
  const eventMap: Record<string, string[]> = {
    REQUESTED: ['SHIPMENT_REQUESTED'],
    PARCEL_CONFIRMED: ['PARCEL_INSPECTED_AND_COLLECTED', 'DELIVERY_CODE_GENERATED'],
    AT_ORIGIN_HUB: ['PARCEL_RECEIVED_AT_ORIGIN_HUB', 'PARCEL_STAGED_AT_ORIGIN', 'BATCH_LOCKED_FOR_DEPARTURE'],
    IN_TRANSIT: ['PARCEL_DEPARTED_ON_CORRIDOR', 'BATCH_ONBOARDED'],
    ARRIVED_DESTINATION: ['SHIPMENT_ARRIVED_DESTINATION'],
    OUT_FOR_DELIVERY: ['PARCEL_OUT_FOR_DELIVERY'],
    DELIVERED: ['SHIPMENT_DELIVERED_TO_RECEIVER'],
  };

  const matchingEventTypes = eventMap[stageKey] || [];
  return milestones.find((m) => matchingEventTypes.includes(m.event_type));
}

export function TrackingTimelineView({ data }: TrackingTimelineViewProps) {
  const currentStatusInfo = getStatusDisplay(data.current_status);
  const currentActiveIndex = currentStatusInfo.stageIndex;

  return (
    <div className="bg-surface-white rounded-2xl border border-border p-6 sm:p-8 space-y-6 shadow-card">
      <div className="border-b border-border pb-4">
        <h3 className="text-base font-bold text-cerelo-navy">
          Verified Lifecycle Progress
        </h3>
        <p className="text-xs text-text-secondary mt-0.5">
          Milestones reflect physical custody handoffs verified in the operational ledger.
        </p>
      </div>

      <ol className="relative border-l-2 border-border ml-3 sm:ml-4 space-y-8 my-4" aria-label="Shipment delivery milestones">
        {LIFECYCLE_STAGES.map((stage, index) => {
          const isCompleted = index < currentActiveIndex || (currentStatusInfo.isTerminal && !currentStatusInfo.isCancelled);
          const isCurrent = index === currentActiveIndex && !currentStatusInfo.isTerminal;
          const isFuture = index > currentActiveIndex;
          const matchedMilestone = findMilestoneForStage(stage.key, data.milestones);

          return (
            <li
              key={stage.key}
              className={cn(
                'relative pl-6 sm:pl-8',
                isFuture && 'opacity-50'
              )}
            >
              {/* Node Icon */}
              <span
                className={cn(
                  'absolute -left-[13px] sm:-left-[15px] top-0 flex items-center justify-center rounded-full transition-all duration-200',
                  isCompleted && 'w-6 h-6 sm:w-7 sm:h-7 bg-status-success text-white shadow-subtle',
                  isCurrent && 'w-6 h-6 sm:w-7 sm:h-7 bg-cerelo-orange text-white shadow-orange-glow animate-pulse-dot',
                  isFuture && 'w-6 h-6 sm:w-7 sm:h-7 bg-surface-subtle border-2 border-border text-text-muted'
                )}
                aria-hidden="true"
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 stroke-[2.5]" />
                ) : isCurrent ? (
                  <Clock className="w-3.5 h-3.5 sm:w-4 sm:h-4 stroke-[2.5]" />
                ) : (
                  <Circle className="w-3 h-3 text-text-muted" />
                )}
              </span>

              {/* Stage Content */}
              <div className="space-y-1">
                <div className="flex flex-col sm:flex-row sm:items-baseline justify-between gap-1">
                  <h4
                    className={cn(
                      'text-sm font-bold',
                      isCompleted && 'text-cerelo-navy',
                      isCurrent && 'text-cerelo-orange text-base font-extrabold',
                      isFuture && 'text-text-muted'
                    )}
                  >
                    {stage.label}
                  </h4>

                  {/* Timestamp if verified in ledger */}
                  {matchedMilestone && (
                    <span className="text-[11px] font-mono text-text-muted shrink-0">
                      {formatMilestoneTime(matchedMilestone.created_at)}
                    </span>
                  )}
                </div>

                <p
                  className={cn(
                    'text-xs leading-relaxed max-w-xl',
                    isCurrent ? 'text-text-primary font-medium' : 'text-text-secondary'
                  )}
                >
                  {isCurrent ? stage.trackingVisibilityText : stage.shortDescription}
                </p>

                <div className="text-[11px] text-text-muted pt-0.5">
                  Custody: <span className="font-medium text-cerelo-navy">{stage.custodyHolder}</span>
                </div>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
