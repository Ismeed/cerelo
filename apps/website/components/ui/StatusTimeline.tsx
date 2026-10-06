import { CheckCircle2, Circle, MapPin } from 'lucide-react';
import { LIFECYCLE_STAGES, type LifecycleStage } from '@/lib/data/stages';
import { cn } from '@/lib/utils';

export interface StatusTimelineProps {
  currentStageKey?: string;
  className?: string;
}

export function StatusTimeline({ currentStageKey = 'REQUESTED', className }: StatusTimelineProps) {
  const currentStageIndex = LIFECYCLE_STAGES.findIndex((s) => s.key === currentStageKey);
  const activeIndex = currentStageIndex === -1 ? 0 : currentStageIndex;

  return (
    <div className={cn('w-full', className)}>
      <ol className="relative border-l-2 border-border ml-4 space-y-0" aria-label="Shipment lifecycle stages">
        {LIFECYCLE_STAGES.map((stage: LifecycleStage, index: number) => {
          const isCompleted = index < activeIndex;
          const isCurrent = index === activeIndex;
          const isPending = index > activeIndex;

          return (
            <li
              key={stage.key}
              className="relative ml-6 pb-7 last:pb-0"
              role="listitem"
              aria-current={isCurrent ? 'step' : undefined}
            >
              {/* Stage node — positioned on the left border */}
              <span
                className={cn(
                  'absolute -left-[2.15rem] top-0',
                  'flex items-center justify-center w-8 h-8 rounded-full border-2 bg-surface-white',
                  'transition-all duration-200',
                  isCompleted && 'border-status-success text-status-success bg-status-success-bg',
                  isCurrent  && 'border-cerelo-orange text-cerelo-orange bg-cerelo-orange-soft ring-4 ring-cerelo-orange/15',
                  isPending  && 'border-border text-text-muted bg-surface-white',
                )}
                aria-hidden="true"
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-4 h-4" strokeWidth={2} />
                ) : isCurrent ? (
                  <MapPin className="w-4 h-4 animate-pulse-dot" strokeWidth={2} />
                ) : (
                  <Circle className="w-3.5 h-3.5" strokeWidth={1.5} />
                )}
              </span>

              {/* Stage content */}
              <div className="pt-0.5 space-y-0.5">
                <div className="flex flex-wrap items-center gap-2 mb-0.5">
                  <p
                    className={cn(
                      'text-sm font-semibold leading-tight',
                      isCompleted && 'text-status-success',
                      isCurrent  && 'text-cerelo-navy font-bold',
                      isPending  && 'text-text-muted',
                    )}
                  >
                    {stage.label}
                  </p>
                  {isCurrent && (
                    <span className="inline-flex items-center text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-cerelo-orange text-white">
                      Now
                    </span>
                  )}
                </div>

                <p className="text-xs text-text-secondary leading-relaxed">
                  {stage.shortDescription}
                </p>
                <p className="text-[11px] text-text-muted mt-0.5">
                  Custody:{' '}
                  <span className="font-medium text-text-secondary">{stage.custodyHolder}</span>
                </p>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
