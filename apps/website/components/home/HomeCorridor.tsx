import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { CORRIDOR_DATA } from '@/lib/data/corridor';

/** CSS-only bidirectional corridor route diagram */
function CorridorRouteDiagram() {
  return (
    <div
      className="relative w-full max-w-lg mx-auto py-8 select-none"
      aria-hidden="true"
    >
      <div className="flex items-center justify-between gap-4">

        {/* Origin city */}
        <div className="flex flex-col items-center gap-3 z-10">
          <div className="w-16 h-16 md:w-20 md:h-20 rounded-2xl bg-white/10 border border-white/25 backdrop-blur-sm flex items-center justify-center shadow-lg">
            <span className="text-2xl md:text-3xl" role="img" aria-label="City">🏙️</span>
          </div>
          <div className="text-center">
            <p className="text-base md:text-lg font-black text-white">{CORRIDOR_DATA.origin.name}</p>
            <p className="text-xs text-white/55 font-medium">{CORRIDOR_DATA.origin.state}</p>
          </div>
        </div>

        {/* Corridor line */}
        <div className="flex-1 flex flex-col items-center gap-2 px-2">
          {/* Forward arrow line */}
          <div className="w-full flex items-center">
            <div className="flex-1 h-px bg-gradient-to-r from-cerelo-orange/60 to-cerelo-orange"/>
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="shrink-0">
              <path d="M0 5h8M5 1l4 4-4 4" stroke="#F4630A" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>

          {/* Hub labels */}
          <div className="flex items-center gap-1">
            <div className="flex flex-col items-center">
              <div className="w-2 h-2 rounded-full bg-cerelo-orange/70 mb-0.5"/>
              <p className="text-[10px] text-white/40 font-medium whitespace-nowrap">Origin Hub</p>
            </div>
            <div className="flex-1 h-px bg-white/10 mx-2" />
            <div className="flex flex-col items-center">
              <div className="w-2 h-2 rounded-full bg-cerelo-orange/70 mb-0.5"/>
              <p className="text-[10px] text-white/40 font-medium whitespace-nowrap">Destination Hub</p>
            </div>
          </div>

          {/* Return arrow line */}
          <div className="w-full flex items-center">
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="shrink-0">
              <path d="M10 5H2M5 1L1 5l4 4" stroke="#FF8534" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            <div className="flex-1 h-px bg-gradient-to-l from-cerelo-orange-light/60 to-cerelo-orange-light"/>
          </div>
        </div>

        {/* Destination city */}
        <div className="flex flex-col items-center gap-3 z-10">
          <div className="w-16 h-16 md:w-20 md:h-20 rounded-2xl bg-white/10 border border-white/25 backdrop-blur-sm flex items-center justify-center shadow-lg">
            <span className="text-2xl md:text-3xl" role="img" aria-label="City">🏙️</span>
          </div>
          <div className="text-center">
            <p className="text-base md:text-lg font-black text-white">{CORRIDOR_DATA.destination.name}</p>
            <p className="text-xs text-white/55 font-medium">{CORRIDOR_DATA.destination.state}</p>
          </div>
        </div>
      </div>
    </div>
  );
}

export function HomeCorridor() {
  return (
    <section
      className="py-section bg-cerelo-navy-deep text-text-inverse"
      aria-labelledby="corridor-heading"
      id="corridor"
    >
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto text-center">

          {/* Eyebrow */}
          <p className="text-overline font-semibold uppercase tracking-widest text-cerelo-orange-light mb-4">
            Kano ↔ Katsina Corridor
          </p>

          {/* Headline */}
          <h2
            id="corridor-heading"
            className="text-h2 font-bold text-white leading-tight mb-4"
          >
            Starting focused.
            <br />
            Serving well.
          </h2>

          <p className="text-body-lg text-white/70 mb-8 max-w-[52ch] mx-auto">
            CERELO currently serves the Kano ↔ Katsina corridor in both directions. We are building operational excellence on this corridor first — so that every delivery we make is one we can stand behind.
          </p>

          {/* Corridor badge */}
          <CorridorBadge size="lg" inverted className="mb-8" />

          {/* Route diagram */}
          <CorridorRouteDiagram />

          {/* Boundary notice */}
          <p className="text-body-sm text-white/40 mt-4 max-w-xl mx-auto leading-relaxed">
            {CORRIDOR_DATA.operationalBoundaryNotice}
          </p>

        </div>
      </div>
    </section>
  );
}
