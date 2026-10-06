import { type ButtonHTMLAttributes, forwardRef } from 'react';
import Link from 'next/link';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'white' | 'destructive';
  size?: 'sm' | 'md' | 'lg';
  href?: string;
  external?: boolean;
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      className,
      variant = 'primary',
      size = 'md',
      href,
      external,
      loading = false,
      children,
      disabled,
      ...props
    },
    ref
  ) => {
    const isDisabled = disabled || loading;

    const baseStyles = [
      'inline-flex items-center justify-center font-semibold rounded-md',
      'transition-all duration-150 ease-smooth',
      'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2',
      'disabled:opacity-50 disabled:pointer-events-none',
      'select-none cursor-pointer',
      'whitespace-nowrap',
    ].join(' ');

    const variantStyles: Record<NonNullable<ButtonProps['variant']>, string> = {
      primary:
        'bg-cerelo-orange text-white hover:bg-cerelo-orange-hover active:scale-[0.98] focus-visible:ring-cerelo-orange shadow-subtle',
      secondary:
        'bg-cerelo-navy text-white hover:bg-cerelo-navy-soft active:scale-[0.98] focus-visible:ring-cerelo-navy',
      outline:
        'border border-border-strong text-text-primary bg-transparent hover:bg-surface-subtle hover:border-cerelo-navy hover:text-cerelo-navy focus-visible:ring-cerelo-navy',
      ghost:
        'text-text-secondary hover:text-cerelo-navy hover:bg-surface-subtle focus-visible:ring-cerelo-navy',
      white:
        'bg-white text-cerelo-navy hover:bg-surface-subtle active:scale-[0.98] focus-visible:ring-white shadow-subtle',
      destructive:
        'bg-status-error text-white hover:bg-red-700 active:scale-[0.98] focus-visible:ring-status-error',
    };

    const sizeStyles: Record<NonNullable<ButtonProps['size']>, string> = {
      sm:  'text-xs  px-3   py-1.5 gap-1.5 h-8  min-w-[2rem]',
      md:  'text-sm  px-4   py-2.5 gap-2   h-10 min-w-[2.5rem]',
      lg:  'text-base px-6  py-3.5 gap-2.5 h-12 min-w-[3rem]',
    };

    const classes = cn(baseStyles, variantStyles[variant], sizeStyles[size], className);

    const content = loading ? (
      <>
        <Loader2 className="w-4 h-4 animate-spin" aria-hidden="true" />
        <span>{children}</span>
      </>
    ) : (
      children
    );

    if (href) {
      if (external) {
        return (
          <a
            href={href}
            target="_blank"
            rel="noopener noreferrer"
            className={classes}
            aria-disabled={isDisabled}
          >
            {content}
          </a>
        );
      }
      return (
        <Link href={href} className={classes} aria-disabled={isDisabled}>
          {content}
        </Link>
      );
    }

    return (
      <button
        ref={ref}
        className={classes}
        disabled={isDisabled}
        aria-busy={loading}
        {...props}
      >
        {content}
      </button>
    );
  }
);

Button.displayName = 'Button';
