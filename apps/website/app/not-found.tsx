import type { Metadata } from 'next';
import Link from 'next/link';
import { ArrowRight, Package, Search, Home } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Button } from '@/components/ui/Button';
import { SITE_CONFIG } from '@/lib/config/site';

export const metadata: Metadata = {
  title: 'Page Not Found — CERELO',
  description: 'The page you are looking for could not be found.',
  robots: {
    index: false,
    follow: false,
  },
};

export default function NotFound() {
  return (
    <div className="py-16 sm:py-24">
      <Container size="narrow">
        <div className="text-center space-y-8 max-w-xl mx-auto">
          {/* 404 Visual */}
          <div className="space-y-4">
            <div
              className="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-surface-subtle border border-border"
              aria-hidden="true"
            >
              <Search className="w-9 h-9 text-cerelo-orange" />
            </div>
            <div>
              <p className="text-7xl sm:text-9xl font-black text-cerelo-navy/10 tracking-tight select-none" aria-hidden="true">
                404
              </p>
            </div>
          </div>

          {/* Message */}
          <div className="space-y-3">
            <h1 className="text-2xl sm:text-3xl font-black text-cerelo-navy tracking-tight">
              Page Not Found
            </h1>
            <p className="text-base text-text-secondary leading-relaxed max-w-sm mx-auto">
              We couldn&apos;t find what you&apos;re looking for. The page may have moved, or the link may be incorrect.
            </p>
          </div>

          {/* Action links */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Button href="/" variant="primary" size="md">
              <Home className="w-4 h-4" aria-hidden="true" />
              Go to Homepage
            </Button>
            <Button
              href={SITE_CONFIG.ctaDestinations.trackShipment.href}
              variant="outline"
              size="md"
            >
              Track a Shipment
              <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
            </Button>
            <Button
              href={SITE_CONFIG.ctaDestinations.sendPackage.href}
              variant="ghost"
              size="md"
            >
              <Package className="w-3.5 h-3.5" aria-hidden="true" />
              Send a Package
            </Button>
          </div>

          {/* Corridor reminder */}
          <p className="text-xs text-text-muted">
            CERELO operates exclusively on the{' '}
            <Link
              href="/how-it-works"
              className="text-cerelo-navy font-semibold hover:underline"
            >
              {SITE_CONFIG.corridor.route} corridor
            </Link>
            .
          </p>
        </div>
      </Container>
    </div>
  );
}
