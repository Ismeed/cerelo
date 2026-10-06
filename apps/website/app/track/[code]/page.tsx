import { Suspense } from 'react';
import type { Metadata } from 'next';
import { SITE_CONFIG } from '@/lib/config/site';
import { TrackPageClient } from '@/components/tracking/TrackPageClient';
import { Container } from '@/components/ui/Container';
import { Loader2 } from 'lucide-react';

interface Props {
  params: Promise<{ code: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { code: rawCode } = await params;
  const code = rawCode.toUpperCase();
  return {
    title: `Tracking ${code} | CERELO`,
    description: `Track your CERELO parcel ${code} across the Kano ↔ Katsina corridor. Verified milestone updates from pickup to doorstep.`,
    alternates: {
      canonical: `${SITE_CONFIG.url}/track/${code}`,
    },
    openGraph: {
      title: `Tracking ${code} | CERELO`,
      description: `Track your CERELO parcel ${code} across the Kano ↔ Katsina corridor.`,
      url: `${SITE_CONFIG.url}/track/${code}`,
    },
  };
}

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

export default async function TrackByCodePage({ params }: Props) {
  const { code } = await params;
  return (
    <Suspense fallback={<TrackPageLoading />}>
      <TrackPageClient initialCode={code} />
    </Suspense>
  );
}
