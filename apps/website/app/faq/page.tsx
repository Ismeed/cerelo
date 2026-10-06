import type { Metadata } from 'next';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Breadcrumbs } from '@/components/ui/Breadcrumbs';
import { Card } from '@/components/ui/Card';
import { FaqFilterSearch } from '@/components/faq/FaqFilterSearch';
import { SITE_CONFIG } from '@/lib/config/site';

export const metadata: Metadata = {
  title: 'Frequently Asked Questions | CERELO',
  description:
    'Find clear answers to common questions about CERELO door-to-door parcel delivery, Kano ↔ Katsina corridor coverage, payments, milestone tracking, and cancellation.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/faq`,
  },
};

export default function FAQPage() {
  const { contact } = SITE_CONFIG;

  return (
    <div>
      <Breadcrumbs items={[{ label: 'Frequently Asked Questions' }]} />

      <div className="py-10 sm:py-16 space-y-12">
        <Container size="content">
          <div className="space-y-4 text-center">
            <Badge variant="orange">Help Center</Badge>
            <h1 className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight max-w-2xl mx-auto">
              Frequently Asked Questions
            </h1>
            <p className="text-base sm:text-lg text-text-secondary max-w-xl mx-auto leading-relaxed">
              Straightforward answers about sending, tracking, payment options, and delivery operations on the Kano ↔ Katsina corridor.
            </p>
          </div>

          {/* ── Interactive FAQ Category Filter & Search ─────────── */}
          <div className="mt-10">
            <FaqFilterSearch />
          </div>

          {/* ── Still Have Questions Card ─────────────────────────── */}
          <Card variant="subtle" className="mt-16 p-8 space-y-4 text-center max-w-2xl mx-auto">
            <h2 className="text-xl font-bold text-cerelo-navy">Still Have Questions?</h2>
            <p className="text-sm text-text-secondary max-w-md mx-auto leading-relaxed">
              Our operations desk is available to assist with active delivery inquiries or merchant setup.
            </p>
            <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
              <Button href="/contact" size="md">
                Contact Operations Desk
              </Button>
              {contact.phone && (
                <Button href={`tel:${contact.phone}`} variant="outline" size="md">
                  Call {contact.phone}
                </Button>
              )}
            </div>
          </Card>
        </Container>
      </div>
    </div>
  );
}
