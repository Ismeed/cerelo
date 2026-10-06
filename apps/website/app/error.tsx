'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { AlertTriangle, RefreshCw, Home } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Button } from '@/components/ui/Button';

interface ErrorPageProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function GlobalError({ error, reset }: ErrorPageProps) {
  useEffect(() => {
    // Log to console in development only — never expose in production UI
    if (process.env.NODE_ENV === 'development') {
      // eslint-disable-next-line no-console
      console.error('[CERELO Error Boundary]', error.digest ?? 'No digest', error.message);
    }
  }, [error]);

  return (
    <div className="py-16 sm:py-24">
      <Container size="narrow">
        <div className="text-center space-y-8 max-w-xl mx-auto">
          {/* Error visual */}
          <div className="space-y-4">
            <div
              className="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-status-warning-bg border border-status-warning/30"
              aria-hidden="true"
            >
              <AlertTriangle className="w-9 h-9 text-status-warning" />
            </div>
          </div>

          {/* Message */}
          <div className="space-y-3">
            <h1 className="text-2xl sm:text-3xl font-black text-cerelo-navy tracking-tight">
              Something went wrong
            </h1>
            <p className="text-base text-text-secondary leading-relaxed max-w-sm mx-auto">
              We encountered an unexpected problem. Please try again — if the issue persists,{' '}
              <Link href="/contact" className="text-cerelo-navy font-semibold hover:underline">
                contact our team
              </Link>
              .
            </p>
          </div>

          {/* Actions */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Button
              onClick={reset}
              variant="primary"
              size="md"
            >
              <RefreshCw className="w-4 h-4" aria-hidden="true" />
              Try Again
            </Button>
            <Button href="/" variant="outline" size="md">
              <Home className="w-4 h-4" aria-hidden="true" />
              Go to Homepage
            </Button>
          </div>
        </div>
      </Container>
    </div>
  );
}
