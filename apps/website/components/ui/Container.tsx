import { type HTMLAttributes, forwardRef } from 'react';
import { cn } from '@/lib/utils';

export interface ContainerProps extends HTMLAttributes<HTMLDivElement> {
  size?: 'default' | 'content' | 'narrow';
}

export const Container = forwardRef<HTMLDivElement, ContainerProps>(
  ({ className, size = 'default', children, ...props }, ref) => {
    return (
      <div
        ref={ref}
        className={cn(
          'w-full mx-auto px-4 sm:px-6 lg:px-8',
          {
            'max-w-site': size === 'default',
            'max-w-content': size === 'content',
            'max-w-narrow': size === 'narrow',
          },
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);

Container.displayName = 'Container';
