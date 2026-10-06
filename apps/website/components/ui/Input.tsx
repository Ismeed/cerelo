import { forwardRef, type InputHTMLAttributes, type TextareaHTMLAttributes, useId } from 'react';
import { cn } from '@/lib/utils';

/* ─── Shared label / error display ─────────────────────────────────────── */
interface FieldWrapperProps {
  label?: string;
  htmlFor: string;
  error?: string;
  helper?: string;
  required?: boolean;
  children: React.ReactNode;
  className?: string;
}

export function FieldWrapper({
  label,
  htmlFor,
  error,
  helper,
  required,
  children,
  className,
}: FieldWrapperProps) {
  return (
    <div className={cn('flex flex-col gap-1.5', className)}>
      {label && (
        <label
          htmlFor={htmlFor}
          className="text-sm font-medium text-text-primary"
        >
          {label}
          {required && (
            <span className="ml-1 text-status-error" aria-hidden="true">*</span>
          )}
        </label>
      )}
      {children}
      {error ? (
        <p id={`${htmlFor}-error`} className="text-body-sm text-status-error" role="alert">
          {error}
        </p>
      ) : helper ? (
        <p id={`${htmlFor}-helper`} className="text-body-sm text-text-muted">
          {helper}
        </p>
      ) : null}
    </div>
  );
}

/* ─── Base input class ──────────────────────────────────────────────────── */
const inputBase = [
  'w-full rounded-md border border-border bg-surface-white px-3.5 py-2.5',
  'text-body font-sans text-text-primary placeholder:text-text-muted',
  'transition-colors duration-150 ease-smooth',
  'focus:outline-none focus:border-cerelo-navy focus:ring-2 focus:ring-cerelo-navy/10',
  'disabled:opacity-50 disabled:bg-surface-subtle disabled:cursor-not-allowed',
  'aria-[invalid=true]:border-status-error aria-[invalid=true]:focus:ring-status-error/10',
].join(' ');

/* ─── Input ─────────────────────────────────────────────────────────────── */
export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  helper?: string;
  wrapperClassName?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, helper, required, wrapperClassName, className, id: externalId, ...props }, ref) => {
    const generatedId = useId();
    const id = externalId ?? generatedId;

    return (
      <FieldWrapper
        label={label}
        htmlFor={id}
        error={error}
        helper={helper}
        required={required}
        className={wrapperClassName}
      >
        <input
          ref={ref}
          id={id}
          required={required}
          aria-required={required}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={
            error ? `${id}-error` : helper ? `${id}-helper` : undefined
          }
          className={cn(inputBase, 'h-11', className)}
          {...props}
        />
      </FieldWrapper>
    );
  }
);
Input.displayName = 'Input';

/* ─── Textarea ──────────────────────────────────────────────────────────── */
export interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  helper?: string;
  wrapperClassName?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ label, error, helper, required, wrapperClassName, className, id: externalId, ...props }, ref) => {
    const generatedId = useId();
    const id = externalId ?? generatedId;

    return (
      <FieldWrapper
        label={label}
        htmlFor={id}
        error={error}
        helper={helper}
        required={required}
        className={wrapperClassName}
      >
        <textarea
          ref={ref}
          id={id}
          required={required}
          aria-required={required}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={
            error ? `${id}-error` : helper ? `${id}-helper` : undefined
          }
          className={cn(inputBase, 'min-h-[120px] resize-y py-3', className)}
          {...props}
        />
      </FieldWrapper>
    );
  }
);
Textarea.displayName = 'Textarea';

/* ─── Select ────────────────────────────────────────────────────────────── */
export interface SelectProps extends InputHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  helper?: string;
  wrapperClassName?: string;
  children: React.ReactNode;
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ label, error, helper, required, wrapperClassName, className, id: externalId, children, ...props }, ref) => {
    const generatedId = useId();
    const id = externalId ?? generatedId;

    return (
      <FieldWrapper
        label={label}
        htmlFor={id}
        error={error}
        helper={helper}
        required={required}
        className={wrapperClassName}
      >
        <select
          ref={ref}
          id={id}
          required={required}
          aria-required={required}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={
            error ? `${id}-error` : helper ? `${id}-helper` : undefined
          }
          className={cn(inputBase, 'h-11 pr-8 appearance-none bg-no-repeat cursor-pointer', className)}
          style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3E%3Cpath stroke='%2398A2B3' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3E%3C/svg%3E")`,
            backgroundPosition: 'right 0.75rem center',
            backgroundSize: '1.25rem',
          }}
          {...props}
        >
          {children}
        </select>
      </FieldWrapper>
    );
  }
);
Select.displayName = 'Select';
