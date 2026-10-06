import { Suspense } from 'react';
import type { Metadata } from 'next';
import { SITE_CONFIG } from '@/lib/config/site';
import { TrackPageClient } from '@/components/tracking/TrackPageClient';
import { Container } from '@/components/ui/Container';
import { Loader2 } from 'lucide-react';

export const metadata: Metadata = {
  title: 'Track a Shipment | CERELO',
  description:
    'Track your CERELO parcel across the Kano ↔ Katsina corridor using your Delivery Code or shared tracking link. Verified milestone updates from pickup to doorstep.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/track`,
  },
  // No query-param tracking URLs appear in metadata — canonical is always /track
  openGraph: {
    title: 'Track a Shipment | CERELO',
    description: 'Track your CERELO parcel across the Kano ↔ Katsina corridor using your Delivery Code.',
    url: `${SITE_CONFIG.url}/track`,
  },
};

function TrackPageLoading() {
  return (
    <div className="py-16 sm:py-24">
      <Container size="narrow">
        <div className="p-12 bg-surface-white rounded-2xl border border-border text-center space-y-3 shadow-subtle">
          <Loader2 className="w-8 h-8 text-cerelo-orange animate-spin mx-auto" aria-hidden="true" />
          <h3 className="text-base font-bold text-cerelo-navy">Loading Tracking Portal...</h3>
        </div>
      </Container>
    </div>
  );
}

export default function TrackPage() {
  return (
    <Suspense fallback={<TrackPageLoading />}>
      <TrackPageClient />
    </Suspense>
  );
}
