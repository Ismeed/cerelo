import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Button } from '@/components/ui/Button';
import { SITE_CONFIG } from '@/lib/config/site';
import { User, Store, Package, Share2, ArrowRight, DoorOpen } from 'lucide-react';

const INDIVIDUAL_BENEFITS = [
  { icon: Package, text: 'Personal packages, documents, and purchases' },
  { icon: DoorOpen, text: 'No motor-park trips — CERELO collects at your door' },
  { icon: Share2, text: 'Share the tracking link with your receiver' },
] as const;

const BUSINESS_BENEFITS = [
  { icon: Store, text: 'Regular shipments from market stalls and online shops' },
  { icon: Package, text: 'CERELO handles the intercity logistics — you focus on selling' },
  { icon: Share2, text: 'Buyers receive shareable tracking links automatically' },
] as const;

export function HomeAudience() {
  return (
    <Section variant="white" labelledBy="audience-heading" id="who-we-serve">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">

        <SectionHeader
          eyebrow="Built for both"
          title="From personal parcels to commercial orders."
          titleId="audience-heading"
          description="CERELO is designed for individuals sending personal items, and merchants who need reliable intercity delivery for their business."
          align="center"
          className="max-w-2xl mx-auto mb-12"
        />

        <div className="grid md:grid-cols-2 gap-5 max-w-4xl mx-auto">

          {/* Individuals card */}
          <div className="group rounded-xl border border-border bg-surface-white p-7 hover:border-cerelo-navy hover:shadow-card-hover transition-all duration-200">
            <div className="w-12 h-12 rounded-xl bg-cerelo-navy/8 flex items-center justify-center mb-5">
              <User className="w-6 h-6 text-cerelo-navy" aria-hidden="true" />
            </div>
            <h3 className="text-h3 font-bold text-text-primary mb-2">For Individuals</h3>
            <p className="text-body-sm text-text-secondary mb-5 leading-relaxed">
              Sending to family, paying back a purchase, or shipping a gift across the corridor — CERELO handles it with the same organized process.
            </p>
            <ul className="space-y-3 mb-6" aria-label="Individual sender benefits">
              {INDIVIDUAL_BENEFITS.map(({ icon: Icon, text }) => (
                <li key={text} className="flex items-start gap-3 text-body-sm text-text-secondary">
                  <Icon className="w-4 h-4 text-cerelo-orange mt-0.5 shrink-0" aria-hidden="true" />
                  {text}
                </li>
              ))}
            </ul>
            <Button
              href={SITE_CONFIG.ctaDestinations.sendPackage.href}
              variant="primary"
              size="md"
            >
              {SITE_CONFIG.ctaDestinations.sendPackage.label}
            </Button>
          </div>

          {/* Businesses card */}
          <div className="group rounded-xl border border-border bg-surface-white p-7 hover:border-cerelo-navy hover:shadow-card-hover transition-all duration-200">
            <div className="w-12 h-12 rounded-xl bg-cerelo-orange-soft flex items-center justify-center mb-5">
              <Store className="w-6 h-6 text-cerelo-orange" aria-hidden="true" />
            </div>
            <h3 className="text-h3 font-bold text-text-primary mb-2">For Merchants & Sellers</h3>
            <p className="text-body-sm text-text-secondary mb-5 leading-relaxed">
              Whether you sell from a market stall or an online shop, CERELO gives you a dependable intercity delivery channel without the logistics overhead.
            </p>
            <ul className="space-y-3 mb-6" aria-label="Business sender benefits">
              {BUSINESS_BENEFITS.map(({ icon: Icon, text }) => (
                <li key={text} className="flex items-start gap-3 text-body-sm text-text-secondary">
                  <Icon className="w-4 h-4 text-cerelo-orange mt-0.5 shrink-0" aria-hidden="true" />
                  {text}
                </li>
              ))}
            </ul>
            <Button
              href="/business"
              variant="outline"
              size="md"
            >
              CERELO for Business
              <ArrowRight className="w-4 h-4" aria-hidden="true" />
            </Button>
          </div>

        </div>
      </div>
    </Section>
  );
}
