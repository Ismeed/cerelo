import { Button } from '@/components/ui/Button';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { SITE_CONFIG } from '@/lib/config/site';
import {
  Package,
  ArrowRight,
  CheckCircle2,
  ClipboardList,
  PackageCheck,
  Truck,
  ShieldCheck,
  DoorOpen,
  Repeat2,
} from 'lucide-react';

const TRUST_SIGNALS = [
  'Door-to-door, both directions',
  'Organized custody at every stage',
  'Status-based parcel visibility',
] as const;

/**
 * Structural facts about the service — deliberately not performance metrics.
 * CERELO has no commercial launch yet, so any "parcels delivered" or
 * "on-time %" figure here would be invented. These describe how the service is
 * built, which is verifiable today.
 */
const SERVICE_FACTS = [
  { icon: DoorOpen, label: 'Door to door', detail: 'Collected and delivered at the address' },
  { icon: Repeat2, label: 'Both directions', detail: 'Kano to Katsina, Katsina to Kano' },
  { icon: ShieldCheck, label: 'Delivery code', detail: 'Every parcel carries a verifiable code' },
] as const;

/** The four custody stages, as icons rather than emoji. */
const STAGES = [
  { label: 'Request', Icon: ClipboardList, tone: 'accent' },
  { label: 'Pickup', Icon: PackageCheck, tone: 'neutral' },
  { label: 'Transit', Icon: Truck, tone: 'neutral' },
  { label: 'Delivery', Icon: CheckCircle2, tone: 'success' },
] as const;

const STAGE_TONES = {
  accent: 'bg-cerelo-orange/15 border-cerelo-orange/40 text-cerelo-orange-light',
  neutral: 'bg-white/[0.06] border-white/15 text-white/75',
  success: 'bg-status-success/10 border-status-success/30 text-status-success',
} as const;

/** Pure CSS/SVG journey illustration — no photos, no stock imagery. */
function JourneyIllustration() {
  return (
    <div className="relative w-full max-w-md mx-auto select-none" aria-hidden="true">
      {/* Glass panel — reads as a lifted surface against the deep navy section */}
      <div className="relative rounded-2xl bg-white/[0.04] border border-white/10 backdrop-blur-sm p-8 shadow-[0_32px_80px_-20px_rgba(0,0,0,0.6)]">

        {/* Route line with animated parcel */}
        <div className="relative flex items-center justify-between mb-10">
          <div className="flex flex-col items-center gap-2 z-10">
            <div className="w-14 h-14 rounded-2xl bg-white/10 border border-white/20 flex items-center justify-center">
              <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                <rect x="4" y="3" width="20" height="23" rx="2" stroke="white" strokeWidth="1.5" fill="none" />
                <path d="M4 8h20" stroke="white" strokeWidth="1.5" strokeOpacity="0.4" />
                <circle cx="19" cy="15" r="1.5" fill="#FF8534" />
              </svg>
            </div>
            <span className="text-xs font-bold text-white/90 tracking-wide">Kano</span>
          </div>

          <div className="flex-1 mx-4 relative h-px">
            <div className="absolute inset-0 bg-gradient-to-r from-white/20 via-cerelo-orange-light to-white/20 rounded-full" />
            <div
              className="absolute top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-cerelo-orange-light shadow-[0_0_14px_rgba(255,133,52,0.9)]"
              style={{ animation: 'slide-parcel 3s ease-in-out infinite', left: '0%' }}
            />
          </div>

          <div className="flex flex-col items-center gap-2 z-10">
            <div className="w-14 h-14 rounded-2xl bg-white/10 border border-white/20 flex items-center justify-center">
              <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                <rect x="4" y="3" width="20" height="23" rx="2" stroke="white" strokeWidth="1.5" fill="none" />
                <path d="M4 8h20" stroke="white" strokeWidth="1.5" strokeOpacity="0.4" />
                <circle cx="19" cy="15" r="1.5" fill="#12B76A" />
              </svg>
            </div>
            <span className="text-xs font-bold text-white/90 tracking-wide">Katsina</span>
          </div>
        </div>

        {/* Four custody stages */}
        <div className="grid grid-cols-4 gap-2">
          {STAGES.map(({ label, Icon, tone }) => (
            <div
              key={label}
              className={`rounded-lg border p-2.5 text-center ${STAGE_TONES[tone]}`}
            >
              <Icon className="w-4 h-4 mx-auto mb-1.5" strokeWidth={2} />
              <p className="text-[10px] font-semibold leading-tight">{label}</p>
            </div>
          ))}
        </div>

        {/* Delivery code example */}
        <div className="mt-6 rounded-xl bg-white/5 border border-white/10 px-4 py-3 flex items-center justify-between">
          <div>
            <p className="text-[10px] text-white/50 uppercase tracking-wider font-semibold mb-0.5">
              Delivery Code
            </p>
            <p className="text-sm font-bold text-white font-mono tracking-wider">CRL–0000–0000</p>
          </div>
          <div className="flex items-center gap-1.5 text-status-success">
            <CheckCircle2 className="w-4 h-4" strokeWidth={2} />
            <span className="text-xs font-semibold">Tracked</span>
          </div>
        </div>
      </div>

      <style>{`
        @keyframes slide-parcel {
          0%   { left: 2%; opacity: 1; }
          45%  { left: 90%; opacity: 1; }
          50%  { left: 90%; opacity: 0; }
          55%  { left: 2%; opacity: 0; }
          60%  { left: 2%; opacity: 1; }
          100% { left: 90%; opacity: 1; }
        }
        @media (prefers-reduced-motion: reduce) {
          @keyframes slide-parcel {
            0%, 100% { left: 50%; opacity: 1; }
          }
        }
      `}</style>
    </div>
  );
}

export function HomeHero() {
  return (
    <section
      className="relative bg-surface-dark overflow-hidden"
      aria-labelledby="hero-heading"
    >
      {/* Depth: a warm glow anchored top-right, and a cool lift bottom-left.
          Kept low-opacity so headline contrast stays well clear of AA. */}
      <div className="absolute inset-0 pointer-events-none" aria-hidden="true">
        <div className="absolute -top-32 -right-24 w-[46rem] h-[46rem] rounded-full bg-cerelo-orange/20 blur-[120px]" />
        <div className="absolute -bottom-40 -left-32 w-[36rem] h-[36rem] rounded-full bg-cerelo-navy-soft/40 blur-[120px]" />
      </div>

      <div className="relative max-w-site mx-auto px-4 sm:px-6 lg:px-8 pt-16 pb-14 md:pt-20 md:pb-20 lg:pt-24 lg:pb-24">
        <div className="grid md:grid-cols-2 gap-12 md:gap-8 lg:gap-16 items-center">

          {/* ── Left: Copy Column ────────────────────────────────────────── */}
          <div className="flex flex-col gap-6 md:gap-7">
            <div>
              <CorridorBadge size="lg" inverted />
            </div>

            <div>
              <h1
                id="hero-heading"
                className="text-display text-white leading-[1.06] tracking-tight mb-5"
              >
                Your door.
                <br />
                <span className="text-white/70">Their door.</span>
                <br />
                <span className="relative inline-block">
                  One <span className="text-cerelo-orange-light">coordinated</span> journey.
                </span>
              </h1>

              <p className="text-body-lg text-white/70 max-w-[52ch]">
                CERELO handles intercity parcel delivery between Kano and Katsina — from your
                doorstep to theirs, organized and tracked at every stage.
              </p>
            </div>

            <div className="flex flex-col xs:flex-row gap-3">
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
                <ArrowRight className="w-4 h-4" aria-hidden="true" />
              </Button>
            </div>

            <ul
              className="flex flex-col sm:flex-row flex-wrap gap-x-5 gap-y-2"
              aria-label="Service highlights"
            >
              {TRUST_SIGNALS.map((signal) => (
                <li key={signal} className="flex items-center gap-2 text-body-sm text-white/70">
                  <CheckCircle2
                    className="w-3.5 h-3.5 text-cerelo-orange-light shrink-0"
                    strokeWidth={2.5}
                    aria-hidden="true"
                  />
                  {signal}
                </li>
              ))}
            </ul>
          </div>

          {/* ── Right: Journey Illustration ─────────────────────────────── */}
          <div className="flex items-center justify-center md:justify-end">
            <JourneyIllustration />
          </div>
        </div>

        {/* ── Service facts strip ──────────────────────────────────────────
            Structural claims only — see SERVICE_FACTS. */}
        <ul className="mt-14 md:mt-16 grid gap-px overflow-hidden rounded-2xl border border-white/10 bg-white/10 sm:grid-cols-3">
          {SERVICE_FACTS.map(({ icon: Icon, label, detail }) => (
            <li key={label} className="bg-surface-dark/95 px-5 py-5 sm:px-6">
              <div className="flex items-center gap-2.5 mb-1.5">
                <Icon className="w-4 h-4 text-cerelo-orange-light shrink-0" strokeWidth={2} aria-hidden="true" />
                <span className="text-sm font-bold text-white tracking-tight">{label}</span>
              </div>
              <p className="text-body-sm text-white/60 leading-relaxed">{detail}</p>
            </li>
          ))}
        </ul>
      </div>

      {/* Bottom accent — marks the seam into the light sections below */}
      <div
        className="h-px bg-gradient-to-r from-transparent via-cerelo-orange/40 to-transparent"
        aria-hidden="true"
      />
    </section>
  );
}
