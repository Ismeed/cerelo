import Link from 'next/link';
import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { AccordionItem } from '@/components/ui/Accordion';
import { FAQ_CATEGORIES } from '@/lib/data/faq';
import { ArrowRight } from 'lucide-react';
import type { FAQItem } from '@/lib/data/faq';

/** IDs of FAQ items to feature on the homepage — chosen for maximum relevance */
const FEATURED_FAQ_IDS = [
  'what-is-cerelo',
  'how-tracking-works',
  'payment-modes',
  'cancel-request-window',
] as const;

/** Pull matching FAQ items from centralized data — preserves single source of truth */
function getFeaturedFAQs(): FAQItem[] {
  const allItems = FAQ_CATEGORIES.flatMap((cat) => cat.items);
  return FEATURED_FAQ_IDS.map(
    (id) => allItems.find((item) => item.id === id)
  ).filter((item): item is FAQItem => item !== undefined);
}

export function HomeFAQPreview() {
  const faqs = getFeaturedFAQs();

  return (
    <Section variant="white" labelledBy="faq-preview-heading" id="faq-preview">
      <div className="max-w-site mx-auto px-4 sm:px-6 lg:px-8">

        <div className="flex flex-col md:flex-row md:items-end md:justify-between gap-6 mb-10">
          <SectionHeader
            eyebrow="Common questions"
            title="Good to know before you send."
            titleId="faq-preview-heading"
            className="md:max-w-md"
          />
          <Link
            href="/faq"
            className="inline-flex items-center gap-2 text-sm font-semibold text-cerelo-orange hover:text-cerelo-orange-hover transition-colors duration-150 shrink-0 group"
            aria-label="View all frequently asked questions"
          >
            View all questions
            <ArrowRight
              className="w-4 h-4 transition-transform duration-150 group-hover:translate-x-0.5"
              aria-hidden="true"
            />
          </Link>
        </div>

        <div className="max-w-3xl space-y-3">
          {faqs.map((faq, index) => (
            <AccordionItem
              key={faq.id}
              id={faq.id}
              question={faq.question}
              answer={faq.answer}
              defaultOpen={index === 0}
            />
          ))}
        </div>

      </div>
    </Section>
  );
}
