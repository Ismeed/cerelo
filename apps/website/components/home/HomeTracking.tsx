import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { StatusTimeline } from '@/components/ui/StatusTimeline';
import { Button } from '@/components/ui/Button';
import { SITE_CONFIG } from '@/lib/config/site';
import { ShieldCheck } from 'lucide-react';

export function HomeTracking() {
  return (
    <Section variant="navy" labelledBy="tracking-heading" id="tracking-visibility">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">

          {/* ── Left: Copy ─────────────────────────────────────────────────── */}
          <div className="flex flex-col gap-6">
            <SectionHeader
              eyebrow="Follow every stage"
              title="Know exactly where your parcel is."
              titleId="tracking-heading"
              description="CERELO records a status update at each verified custody handoff — no simulated GPS, no guessing. Only what has actually happened with your parcel."
              inverted
              className="max-w-full"
            />

            {/* Privacy notice */}
            <div className="flex items-start gap-3 rounded-lg bg-white/8 border border-white/15 px-4 py-3.5">
              <ShieldCheck
                className="w-4 h-4 text-cerelo-orange-light mt-0.5 shrink-0"
                strokeWidth={2}
                aria-hidden="true"
              />
              <p className="text-body-sm text-white/70 leading-relaxed">
                Tracking links protect your privacy — only masked names and city-level routing are ever shared publicly.
              </p>
            </div>

            <div>
              <Button
                href={SITE_CONFIG.ctaDestinations.trackShipment.href}
                variant="white"
                size="md"
              >
                {SITE_CONFIG.ctaDestinations.trackShipment.label}
              </Button>
            </div>
          </div>

          {/* ── Right: StatusTimeline ─────────────────────────────────────── */}
          <div className="relative">
            {/* Example label */}
            <div className="mb-4 flex items-center gap-2">
              <span className="inline-flex items-center text-[10px] uppercase font-bold tracking-wider px-2.5 py-1 rounded-full bg-white/10 border border-white/20 text-white/60">
                Example shipment in progress
              </span>
            </div>

            {/* Timeline card */}
            <div className="rounded-xl bg-white/8 border border-white/15 p-5 md:p-6">
              {/* Delivery code header */}
              <div className="flex items-center justify-between mb-5 pb-4 border-b border-white/15">
                <div>
                  <p className="text-[10px] text-white/50 uppercase tracking-wider font-semibold mb-0.5">Delivery Code</p>
                  <p className="text-sm font-bold text-white font-mono tracking-wider">CRL–XXXX–XXXX</p>
                </div>
                <span className="inline-flex items-center text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-full bg-status-info/20 border border-status-info/30 text-status-info">
                  In Transit
                </span>
              </div>

              {/* Timeline — override colors for navy bg */}
              <div className="[&_ol]:border-l-white/20 [&_.bg-surface-white]:bg-transparent [&_.border-border]:border-white/20 [&_.text-text-secondary]:text-white/65 [&_.text-text-muted]:text-white/40 [&_.text-text-primary]:text-white">
                <StatusTimeline currentStageKey="IN_TRANSIT" />
              </div>
            </div>
          </div>

        </div>
      </div>
    </Section>
  );
}
