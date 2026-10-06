import { Button } from '@/components/ui/Button';
import { SITE_CONFIG } from '@/lib/config/site';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { Package } from 'lucide-react';

export function HomeCTA() {
  return (
    <section
      className="py-section bg-cerelo-navy text-text-inverse"
      aria-labelledby="final-cta-heading"
    >
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">
        <div className="max-w-2xl mx-auto text-center flex flex-col items-center gap-6">

          {/* Corridor badge */}
          <CorridorBadge size="md" inverted />

          {/* Headline */}
          <h2
            id="final-cta-heading"
            className="text-h2 font-bold text-white leading-tight"
          >
            From your door in Kano — or Katsina — to theirs.
          </h2>

          {/* Supporting */}
          <p className="text-body-lg text-white/70 max-w-[48ch]">
            Request a pickup today. CERELO Personnel will collect at your address and deliver directly to the receiver&rsquo;s door.
          </p>

          {/* CTAs */}
          <div className="flex flex-col xs:flex-row gap-3 mt-2">
            <Button
              href={SITE_CONFIG.ctaDestinations.sendPackage.href}
              variant="primary"
              size="lg"
              className="shadow-orange-glow"
            >
              <Package className="w-4 h-4" aria-hidden="true" />
              {SITE_CONFIG.ctaDestinations.sendPackage.label}
            </Button>
            <Button
              href={SITE_CONFIG.ctaDestinations.trackShipment.href}
              variant="white"
              size="lg"
            >
              {SITE_CONFIG.ctaDestinations.trackShipment.label}
            </Button>
          </div>

        </div>
      </div>
    </section>
  );
}
