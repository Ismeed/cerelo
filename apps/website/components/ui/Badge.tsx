import { type HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'corridor' | 'neutral' | 'orange' | 'success' | 'warning' | 'error';
}

export function Badge({
  className,
  variant = 'neutral',
  children,
  ...props
}: BadgeProps) {
  const variantStyles = {
    corridor:
      'bg-cerelo-navy/5 text-cerelo-navy border border-cerelo-navy/15 font-semibold',
    neutral:
      'bg-surface-subtle text-text-secondary border border-border font-medium',
    orange:
      'bg-cerelo-orange-soft text-cerelo-orange border border-cerelo-orange/25 font-semibold',
    success:
      'bg-status-success-bg text-status-success border border-status-success/25 font-semibold',
    warning:
      'bg-status-warning-bg text-status-warning border border-status-warning/25 font-semibold',
    error:
      'bg-status-error-bg text-status-error border border-status-error/25 font-semibold',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 px-2.5 py-1 text-xs rounded-full leading-none transition-colors duration-150',
        variantStyles[variant],
        className
      )}
      {...props}
    >
      {children}
    </span>
  );
}
