import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { X, Check } from 'lucide-react';

const BEFORE_ITEMS = [
  'Travel to the motor park yourself',
  'Negotiate price with individual drivers',
  'No documentation or receipt',
  'Receiver waits at a distant park to collect',
  'No updates if the parcel is delayed',
] as const;

const AFTER_ITEMS = [
  'CERELO Personnel collect at your door',
  'Clear pricing, confirmed at pickup',
  'Every handoff is officially recorded',
  'Receiver gets doorstep delivery',
  'Status updates at each verified stage',
] as const;

export function HomeProblem() {
  return (
    <Section variant="subtle" labelledBy="problem-heading" id="better-way">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">

        <SectionHeader
          eyebrow="A better way to ship"
          title="Intercity shipping used to mean motor-park coordination."
          titleId="problem-heading"
          description="CERELO replaces the informal chaos with an organized, door-to-door system where every stage is recorded."
          align="center"
          className="max-w-2xl mx-auto mb-12"
        />

        {/* Comparison panel */}
        <div className="grid md:grid-cols-2 gap-4 md:gap-6 max-w-3xl mx-auto">

          {/* Before panel */}
          <div className="rounded-xl border border-border bg-surface-white p-6 md:p-7">
            <div className="flex items-center gap-2.5 mb-5">
              <div className="w-8 h-8 rounded-full bg-status-error-bg border border-status-error/20 flex items-center justify-center shrink-0">
                <X className="w-4 h-4 text-status-error" strokeWidth={2.5} aria-hidden="true" />
              </div>
              <h3 className="text-sm font-bold text-text-primary uppercase tracking-wide">The usual experience</h3>
            </div>
            <ul className="space-y-3" aria-label="Common intercity shipping challenges">
              {BEFORE_ITEMS.map((item) => (
                <li key={item} className="flex items-start gap-3 text-body-sm text-text-secondary">
                  <span
                    className="mt-0.5 w-4 h-4 rounded-full bg-status-error-bg flex items-center justify-center shrink-0"
                    aria-hidden="true"
                  >
                    <X className="w-2.5 h-2.5 text-status-error" strokeWidth={3} />
                  </span>
                  {item}
                </li>
              ))}
            </ul>
          </div>

          {/* After panel */}
          <div className="rounded-xl border border-cerelo-orange/25 bg-cerelo-orange-soft p-6 md:p-7 shadow-card">
            <div className="flex items-center gap-2.5 mb-5">
              <div className="w-8 h-8 rounded-full bg-cerelo-orange text-white flex items-center justify-center shrink-0">
                <Check className="w-4 h-4" strokeWidth={2.5} aria-hidden="true" />
              </div>
              <h3 className="text-sm font-bold text-cerelo-navy uppercase tracking-wide">The CERELO difference</h3>
            </div>
            <ul className="space-y-3" aria-label="CERELO advantages">
              {AFTER_ITEMS.map((item) => (
                <li key={item} className="flex items-start gap-3 text-body-sm text-text-secondary">
                  <span
                    className="mt-0.5 w-4 h-4 rounded-full bg-cerelo-orange flex items-center justify-center shrink-0"
                    aria-hidden="true"
                  >
                    <Check className="w-2.5 h-2.5 text-white" strokeWidth={3} />
                  </span>
                  {item}
                </li>
              ))}
            </ul>
          </div>
        </div>

      </div>
    </Section>
  );
}
