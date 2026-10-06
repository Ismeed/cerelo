'use client';

import { useState, useEffect, useCallback } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { TrackingSearchForm } from '@/components/tracking/TrackingSearchForm';
import { TrackingSummaryCard } from '@/components/tracking/TrackingSummaryCard';
import { TrackingTimelineView } from '@/components/tracking/TrackingTimelineView';
import { TrackingEmptyState } from '@/components/tracking/TrackingEmptyState';
import { TrackingErrorState } from '@/components/tracking/TrackingErrorState';
import { TrackingCancelledView } from '@/components/tracking/TrackingCancelledView';
import { fetchPublicShipmentTracking } from '@/lib/supabase/client';
import { normalizeTrackingQuery } from '@/lib/tracking/normalize';
import type { PublicTrackingData } from '@/lib/types/tracking';
import { Loader2 } from 'lucide-react';

type LookupState =
  | { status: 'idle' }
  | { status: 'loading'; query: string }
  | { status: 'success'; data: PublicTrackingData }
  | { status: 'error'; errorCode: string };

interface TrackPageClientProps {
  initialCode?: string;
}

export function TrackPageClient({ initialCode }: TrackPageClientProps = {}) {
  const searchParams = useSearchParams();
  const router = useRouter();

  const codeParam = searchParams.get('code');
  const tokenParam = searchParams.get('token');
  const initialParam = initialCode || codeParam || tokenParam || '';

  const [state, setState] = useState<LookupState>({ status: 'idle' });

  const executeLookup = useCallback(async (query: string) => {
    const trimmed = normalizeTrackingQuery(query);
    if (!trimmed) {
      setState({ status: 'idle' });
      return;
    }

    setState({ status: 'loading', query: trimmed });

    try {
      const result = await fetchPublicShipmentTracking(trimmed);

      if (result.is_valid) {
        setState({ status: 'success', data: result });
        // Sanitize share token from visible URL to avoid propagation into history/shares
        if (result.lookup_type === 'SHARE_TOKEN' && result.delivery_code) {
          router.replace(`/track?code=${encodeURIComponent(result.delivery_code)}`, { scroll: false });
        }
      } else {
        setState({ status: 'error', errorCode: result.error || 'SHIPMENT_NOT_FOUND' });
      }
    } catch {
      setState({ status: 'error', errorCode: 'NETWORK_ERROR' });
    }
  }, [router]);

  // Perform initial search if query parameter is present in URL
  useEffect(() => {
    if (initialParam) {
      executeLookup(initialParam);
    }
  }, [initialParam, executeLookup]);

  const handleSearch = (newQuery: string) => {
    // Write the *normalized* value to the URL — a pasted share link or share
    // message must not land verbatim in ?code=.
    const normalized = normalizeTrackingQuery(newQuery);
    if (normalized) {
      const param = /^[0-9a-f]{32}$/i.test(normalized) ? 'token' : 'code';
      router.replace(`/track?${param}=${encodeURIComponent(normalized)}`, { scroll: false });
    }
    executeLookup(newQuery);
  };

  const handleRetry = () => {
    router.replace('/track', { scroll: false });
    setState({ status: 'idle' });
  };

  return (
    <div className="py-10 sm:py-16 space-y-10">
      <Container size="narrow">
        {/* ── Page Header ────────────────────────────────────────── */}
        <div className="space-y-4 text-center">
          <div className="flex justify-center items-center gap-2">
            <Badge variant="orange">Live Shipment Visibility</Badge>
            <CorridorBadge size="sm" />
          </div>
          <h1 className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight">
            Track Your Shipment
          </h1>
          <p className="text-base sm:text-lg text-text-secondary max-w-lg mx-auto leading-relaxed">
            Enter your Delivery Code or open your shared tracking link to see verified milestone updates from origin to doorstep.
          </p>
        </div>

        {/* ── Search Form ────────────────────────────────────────── */}
        <div className="mt-8">
          <TrackingSearchForm
            initialQuery={initialParam}
            isLoading={state.status === 'loading'}
            onSearch={handleSearch}
          />
        </div>

        {/* ── Live Region / Results Container ───────────────────── */}
        <div className="mt-8 space-y-8" aria-live="polite">
          {/* Loading State */}
          {state.status === 'loading' && (
            <div className="p-12 bg-surface-white rounded-2xl border border-border text-center space-y-3 shadow-subtle animate-fade-in">
              <Loader2 className="w-8 h-8 text-cerelo-orange animate-spin mx-auto" aria-hidden="true" />
              <h3 className="text-base font-bold text-cerelo-navy">
                Checking Operational Ledger...
              </h3>
              <p className="text-xs text-text-secondary">
                Verifying shipment milestones on the Kano ↔ Katsina corridor.
              </p>
            </div>
          )}

          {/* Error State */}
          {state.status === 'error' && (
            <TrackingErrorState
              errorCode={state.errorCode}
              onRetry={handleRetry}
            />
          )}

          {/* Success State */}
          {state.status === 'success' && (
            <div className="space-y-8 animate-fade-in">
              {state.data.current_status === 'CANCELLED' ? (
                <TrackingCancelledView data={state.data} />
              ) : (
                <>
                  <TrackingSummaryCard data={state.data} />
                  <TrackingTimelineView data={state.data} />
                </>
              )}
            </div>
          )}

          {/* Idle State */}
          {state.status === 'idle' && (
            <div className="animate-fade-in">
              <TrackingEmptyState />
            </div>
          )}
        </div>
      </Container>
    </div>
  );
}
