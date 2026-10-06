import { cn } from '@/lib/utils';
import { ArrowLeftRight } from 'lucide-react';

export interface CorridorBadgeProps {
  /** Override the two city names */
  from?: string;
  to?: string;
  /** Visual size */
  size?: 'sm' | 'md' | 'lg';
  /** Invert colors for dark section backgrounds */
  inverted?: boolean;
  className?: string;
}

const sizeClasses = {
  sm: { wrapper: 'gap-1.5 text-xs',   city: 'text-xs font-semibold px-2 py-0.5 rounded-xs', arrow: 'w-3 h-3' },
  md: { wrapper: 'gap-2   text-sm',   city: 'text-sm font-semibold px-3 py-1   rounded-xs', arrow: 'w-4 h-4' },
  lg: { wrapper: 'gap-3   text-base', city: 'text-base font-bold  px-4 py-1.5 rounded-sm', arrow: 'w-5 h-5' },
};

export function CorridorBadge({
  from = 'Kano',
  to = 'Katsina',
  size = 'md',
  inverted = false,
  className,
}: CorridorBadgeProps) {
  const s = sizeClasses[size];

  return (
    <div
      className={cn(
        'inline-flex items-center',
        s.wrapper,
        className
      )}
      role="presentation"
      aria-label={`${from} to ${to} bidirectional corridor`}
    >
      {/* Origin city chip */}
      <span
        className={cn(
          s.city,
          inverted
            ? 'bg-white/15 text-white'
            : 'bg-cerelo-navy text-white'
        )}
      >
        {from}
      </span>

      {/* Bidirectional arrow */}
      <ArrowLeftRight
        className={cn(
          s.arrow,
          inverted ? 'text-cerelo-orange-light' : 'text-cerelo-orange'
        )}
        aria-hidden="true"
        strokeWidth={2.5}
      />

      {/* Destination city chip */}
      <span
        className={cn(
          s.city,
          inverted
            ? 'bg-white/15 text-white'
            : 'bg-cerelo-navy text-white'
        )}
      >
        {to}
      </span>
    </div>
  );
}
