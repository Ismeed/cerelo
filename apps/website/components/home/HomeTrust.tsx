import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { UserCheck, ClipboardList, Bell } from 'lucide-react';

const TRUST_PILLARS = [
  {
    icon: UserCheck,
    title: 'Authorized Personnel',
    description:
      'Every pickup and delivery is handled by CERELO-assigned and authorized Personnel. No anonymous third-party handlers.',
  },
  {
    icon: ClipboardList,
    title: 'Organized Handoffs',
    description:
      'Each custody transfer is recorded in our operational ledger. No gaps, no undocumented exchanges — a clear chain of responsibility.',
  },
  {
    icon: Bell,
    title: 'Customer Visibility',
    description:
      'Status updates reach you at each verified stage so you always know what has actually happened with your parcel.',
  },
] as const;

export function HomeTrust() {
  return (
    <Section variant="subtle" labelledBy="trust-heading" id="trust-custody">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">

        <SectionHeader
          eyebrow="One journey. Clear responsibility."
          title="CERELO manages every stage of the chain."
          titleId="trust-heading"
          description="There is no gap in the chain where your parcel is unaccounted for. From sender door to receiver door, custody is always defined."
          align="center"
          className="max-w-2xl mx-auto mb-12"
        />

        <div className="grid sm:grid-cols-3 gap-5 max-w-4xl mx-auto">
          {TRUST_PILLARS.map(({ icon: Icon, title, description }) => (
            <div
              key={title}
              className="rounded-xl bg-surface-white border border-border p-6 hover:border-cerelo-navy/30 hover:shadow-card transition-all duration-200"
            >
              {/* Icon */}
              <div className="w-11 h-11 rounded-lg bg-cerelo-navy flex items-center justify-center mb-4 shrink-0">
                <Icon className="w-5 h-5 text-white" aria-hidden="true" strokeWidth={2} />
              </div>

              <h3 className="text-h3 font-bold text-text-primary mb-2">{title}</h3>
              <p className="text-body-sm text-text-secondary leading-relaxed">{description}</p>
            </div>
          ))}
        </div>

      </div>
    </Section>
  );
}
