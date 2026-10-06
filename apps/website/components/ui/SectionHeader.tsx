import { cn } from '@/lib/utils';
import type { ReactNode } from 'react';

export interface SectionHeaderProps {
  eyebrow?: string;
  title: string;
  titleId?: string;
  description?: string;
  align?: 'left' | 'center';
  /** Invert colors for dark/navy section backgrounds */
  inverted?: boolean;
  action?: ReactNode;
  className?: string;
}

export function SectionHeader({
  eyebrow,
  title,
  titleId,
  description,
  align = 'left',
  inverted = false,
  action,
  className,
}: SectionHeaderProps) {
  const isCenter = align === 'center';

  return (
    <div
      className={cn(
        'max-w-reading',
        isCenter && 'mx-auto text-center',
        className
      )}
    >
      {eyebrow && (
        <p
          className={cn(
            'text-overline font-semibold uppercase tracking-widest mb-3',
            inverted
              ? 'text-cerelo-orange-light'
              : 'text-cerelo-orange'
          )}
        >
          {eyebrow}
        </p>
      )}

      <h2
        id={titleId}
        className={cn(
          'text-h2 font-bold leading-tight',
          inverted ? 'text-text-inverse' : 'text-text-primary',
          description ? 'mb-4' : 'mb-0'
        )}
      >
        {title}
      </h2>

      {description && (
        <p
          className={cn(
            'text-body-lg max-w-reading',
            inverted ? 'text-text-inverse/75' : 'text-text-secondary',
            isCenter && 'mx-auto',
            action ? 'mb-6' : 'mb-0'
          )}
        >
          {description}
        </p>
      )}

      {action && (
        <div className={cn('mt-6', isCenter && 'flex justify-center')}>
          {action}
        </div>
      )}
    </div>
  );
}
