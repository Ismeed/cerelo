'use client';

import { useState } from 'react';
import { Search, Loader2, X } from 'lucide-react';
import { Button } from '@/components/ui/Button';
import { cn } from '@/lib/utils';
import { normalizeTrackingQuery } from '@/lib/tracking/normalize';

interface TrackingSearchFormProps {
  initialQuery?: string;
  isLoading: boolean;
  onSearch: (query: string) => void;
}

export function TrackingSearchForm({
  initialQuery = '',
  isLoading,
  onSearch,
}: TrackingSearchFormProps) {
  const [query, setQuery] = useState(initialQuery);
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setQuery(e.target.value);
    if (validationError) setValidationError(null);
  };

  // Users paste a share link or the whole share message far more often than a
  // bare code. Resolve it on paste so they immediately see the code we'll track,
  // rather than submitting a URL and getting "not found".
  const handlePaste = (e: React.ClipboardEvent<HTMLInputElement>) => {
    const pasted = e.clipboardData.getData('text');
    if (!pasted) return;
    const normalized = normalizeTrackingQuery(pasted);
    if (normalized && normalized !== pasted.trim()) {
      e.preventDefault();
      setQuery(normalized);
      if (validationError) setValidationError(null);
    }
  };

  const handleClear = () => {
    setQuery('');
    setValidationError(null);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = query.trim();

    if (!trimmed) {
      setValidationError('Please enter a Delivery Code or Share Token.');
      return;
    }

    onSearch(normalizeTrackingQuery(trimmed));
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="p-6 sm:p-8 bg-surface-white rounded-2xl border border-border shadow-subtle space-y-4"
    >
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <label
            htmlFor="tracking-input"
            className="block text-xs font-bold uppercase tracking-wider text-cerelo-navy"
          >
            Delivery Code or Share Token
          </label>
          <span className="text-[11px] text-text-muted">
            Format: <span className="font-mono font-medium text-cerelo-navy">CRL-XXXX-XXXX</span>
          </span>
        </div>

        <div className="flex flex-col sm:flex-row gap-3">
          <div className="relative flex-grow">
            <input
              id="tracking-input"
              type="text"
              value={query}
              onChange={handleInputChange}
              onPaste={handlePaste}
              placeholder="e.g. CRL-2B8K-9X4M"
              autoComplete="off"
              autoCorrect="off"
              spellCheck="false"
              className={cn(
                'w-full px-4 py-3 border rounded-xl text-base font-mono uppercase tracking-wider text-cerelo-navy bg-surface-white',
                'placeholder:text-text-muted placeholder:normal-case placeholder:font-sans',
                'focus:outline-none focus:ring-2 focus:ring-cerelo-orange focus:border-transparent',
                'transition-all duration-150',
                validationError ? 'border-status-error' : 'border-border-strong'
              )}
              aria-invalid={validationError ? 'true' : 'false'}
              aria-describedby={validationError ? 'tracking-error-msg' : undefined}
            />

            {query && !isLoading && (
              <button
                type="button"
                onClick={handleClear}
                className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-text-muted hover:text-text-primary rounded-md"
                aria-label="Clear input"
              >
                <X className="w-4 h-4" />
              </button>
            )}
          </div>

          <Button
            type="submit"
            size="md"
            disabled={isLoading}
            className="sm:w-36 justify-center shadow-subtle shrink-0"
          >
            {isLoading ? (
              <>
                <Loader2 className="w-4 h-4 mr-2 animate-spin" aria-hidden="true" />
                <span>Searching...</span>
              </>
            ) : (
              <>
                <Search className="w-4 h-4 mr-1.5" aria-hidden="true" />
                <span>Track</span>
              </>
            )}
          </Button>
        </div>

        {validationError && (
          <p
            id="tracking-error-msg"
            role="alert"
            className="text-xs font-medium text-status-error pt-1"
          >
            {validationError}
          </p>
        )}
      </div>
    </form>
  );
}
