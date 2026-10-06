import { type HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

export type SectionVariant = 'white' | 'subtle' | 'navy' | 'dark' | 'orange-tint';

export interface SectionProps extends HTMLAttributes<HTMLElement> {
  variant?: SectionVariant;
  /** aria-labelledby value — required for screen reader landmark navigation */
  labelledBy?: string;
  as?: 'section' | 'div' | 'article';
  tight?: boolean;
}

const variantClasses: Record<SectionVariant, string> = {
  white:        'bg-surface-white',
  subtle:       'bg-surface-subtle border-y border-border',
  navy:         'bg-cerelo-navy text-text-inverse',
  dark:         'bg-surface-dark text-text-inverse',
  'orange-tint':'bg-cerelo-orange-soft border-y border-cerelo-orange/20',
};

export function Section({
  variant = 'white',
  labelledBy,
  as: Tag = 'section',
  tight = false,
  className,
  children,
  ...props
}: SectionProps) {
  return (
    <Tag
      className={cn(
        tight ? 'py-section-sm' : 'py-section',
        variantClasses[variant],
        className
      )}
      aria-labelledby={labelledBy}
      {...props}
    >
      {children}
    </Tag>
  );
}
