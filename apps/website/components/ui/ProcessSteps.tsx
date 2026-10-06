import { type ReactNode } from 'react';
import { cn } from '@/lib/utils';

export interface ProcessStep {
  number: number;
  label: string;
  description: string;
  icon?: ReactNode;
}

export interface ProcessStepsProps {
  steps: ProcessStep[];
  /** Layout direction */
  orientation?: 'horizontal' | 'vertical';
  /** Colors on dark backgrounds */
  inverted?: boolean;
  className?: string;
}

export function ProcessSteps({
  steps,
  orientation = 'horizontal',
  inverted = false,
  className,
}: ProcessStepsProps) {
  const isHorizontal = orientation === 'horizontal';

  return (
    <div
      className={cn(
        isHorizontal
          ? 'flex flex-col sm:flex-row items-start gap-6 sm:gap-0'
          : 'flex flex-col gap-6',
        className
      )}
    >
      {steps.map((step, index) => {
        const isLast = index === steps.length - 1;
        return (
          <div
            key={step.number}
            className={cn(
              'relative flex',
              isHorizontal
                ? 'flex-col items-center text-center flex-1'
                : 'flex-row items-start gap-5 text-left'
            )}
          >
            {/* Connector line between steps */}
            {!isLast && isHorizontal && (
              <div
                className={cn(
                  'hidden sm:block absolute top-5 left-[calc(50%+1.75rem)] right-[-calc(50%-1.75rem)] h-px',
                  inverted ? 'bg-white/20' : 'bg-border-strong'
                )}
                aria-hidden="true"
              />
            )}
            {!isLast && !isHorizontal && (
              <div
                className="absolute left-5 top-10 bottom-[-1.5rem] w-px bg-border"
                aria-hidden="true"
              />
            )}

            {/* Step node */}
            <div
              className={cn(
                'relative z-10 flex items-center justify-center rounded-full font-bold text-sm flex-shrink-0',
                isHorizontal
                  ? 'w-10 h-10 mb-4'
                  : 'w-10 h-10 mt-0',
                inverted
                  ? 'bg-cerelo-orange text-white'
                  : 'bg-cerelo-orange text-white',
              )}
              aria-hidden="true"
            >
              {step.icon ?? step.number}
            </div>

            {/* Step content */}
            <div className={cn(isHorizontal ? 'px-2' : '')}>
              <p
                className={cn(
                  'font-semibold text-sm mb-1',
                  inverted ? 'text-text-inverse' : 'text-text-primary'
                )}
              >
                {step.label}
              </p>
              <p
                className={cn(
                  'text-body-sm',
                  inverted ? 'text-text-inverse/70' : 'text-text-secondary'
                )}
              >
                {step.description}
              </p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
