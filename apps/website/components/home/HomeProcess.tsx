import Link from 'next/link';
import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { ProcessSteps } from '@/components/ui/ProcessSteps';
import { ArrowRight, Smartphone, UserCheck, ArrowLeftRight, HomeIcon } from 'lucide-react';
import type { ProcessStep } from '@/components/ui/ProcessSteps';

const HOME_PROCESS_STEPS: ProcessStep[] = [
  {
    number: 1,
    label: 'Request',
    description: 'Open the CERELO app, enter the destination address, describe the parcel, and choose who pays.',
    icon: <Smartphone className="w-5 h-5" aria-hidden="true" />,
  },
  {
    number: 2,
    label: 'Pickup',
    description: 'CERELO Personnel arrive at your door, inspect the parcel, and take official custody. You receive your Delivery Code.',
    icon: <UserCheck className="w-5 h-5" aria-hidden="true" />,
  },
  {
    number: 3,
    label: 'Transit',
    description: 'Your parcel is consolidated at the origin hub and coordinated across the Kano ↔ Katsina corridor.',
    icon: <ArrowLeftRight className="w-5 h-5" aria-hidden="true" />,
  },
  {
    number: 4,
    label: 'Delivery',
    description: 'Destination Personnel deliver directly to the receiver\'s doorstep. No trips to motor parks.',
    icon: <HomeIcon className="w-5 h-5" aria-hidden="true" />,
  },
];

export function HomeProcess() {
  return (
    <Section variant="white" labelledBy="process-heading" id="how-it-works-preview">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">

        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-6 mb-12">
          <SectionHeader
            eyebrow="The journey, step by step"
            title="Four stages. One coordinated chain."
            titleId="process-heading"
            description="Every CERELO shipment follows the same organized process — from your door in Kano to theirs in Katsina, or the reverse."
            className="md:max-w-xl"
          />
          <Link
            href="/how-it-works"
            className="inline-flex items-center gap-2 text-sm font-semibold text-cerelo-orange hover:text-cerelo-orange-hover transition-colors duration-150 shrink-0 group"
            aria-label="Explore the full 7-stage lifecycle"
          >
            Explore the full lifecycle
            <ArrowRight
              className="w-4 h-4 transition-transform duration-150 group-hover:translate-x-0.5"
              aria-hidden="true"
            />
          </Link>
        </div>

        <ProcessSteps
          steps={HOME_PROCESS_STEPS}
          orientation="horizontal"
          className="max-w-4xl"
        />

      </div>
    </Section>
  );
}
