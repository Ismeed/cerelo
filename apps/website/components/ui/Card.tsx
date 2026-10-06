import { type HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

export type CardVariant = 'default' | 'subtle' | 'bordered' | 'elevated' | 'navy' | 'orange-tint';

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  padding?: 'none' | 'sm' | 'md' | 'lg';
  hoverable?: boolean;
}

const variantClasses: Record<CardVariant, string> = {
  default:
    'bg-surface-white border border-border rounded-lg',
  subtle:
    'bg-surface-subtle border border-border rounded-lg',
  bordered:
    'bg-surface-white border-2 border-border-strong rounded-lg',
  elevated:
    'bg-surface-white rounded-lg shadow-card',
  navy:
    'bg-cerelo-navy text-text-inverse rounded-lg',
  'orange-tint':
    'bg-cerelo-orange-soft border border-cerelo-orange/20 rounded-lg',
};

const paddingClasses: Record<NonNullable<CardProps['padding']>, string> = {
  none: '',
  sm:   'p-4',
  md:   'p-card',
  lg:   'p-card-lg',
};

export function Card({
  variant = 'default',
  padding = 'md',
  hoverable = false,
  className,
  children,
  ...props
}: CardProps) {
  return (
    <div
      className={cn(
        variantClasses[variant],
        paddingClasses[padding],
        hoverable && [
          'transition-shadow duration-200 ease-smooth',
          'hover:shadow-card-hover',
          variant === 'default' || variant === 'elevated' || variant === 'subtle'
            ? 'hover:border-border-strong'
            : '',
        ],
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}
