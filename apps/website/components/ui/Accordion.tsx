'use client';

import { useState, useRef, useEffect } from 'react';
import { ChevronDown } from 'lucide-react';
import { cn } from '@/lib/utils';

export interface AccordionItemProps {
  id: string;
  question: string;
  answer: string;
  defaultOpen?: boolean;
}

export function AccordionItem({ id, question, answer, defaultOpen = false }: AccordionItemProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  const contentRef = useRef<HTMLDivElement>(null);
  const [contentHeight, setContentHeight] = useState<number>(0);

  useEffect(() => {
    if (contentRef.current) {
      setContentHeight(contentRef.current.scrollHeight);
    }
  }, [answer]);

  return (
    <div
      className={cn(
        'border rounded-lg overflow-hidden bg-surface-white transition-colors duration-150',
        isOpen ? 'border-border-strong' : 'border-border'
      )}
    >
      <h3>
        <button
          type="button"
          onClick={() => setIsOpen((prev) => !prev)}
          aria-expanded={isOpen}
          aria-controls={`faq-answer-${id}`}
          id={`faq-question-${id}`}
          className={cn(
            'w-full text-left px-5 py-4 flex items-center justify-between gap-4',
            'font-semibold text-sm text-text-primary',
            'hover:text-cerelo-navy transition-colors duration-150',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-cerelo-orange',
            isOpen && 'text-cerelo-navy'
          )}
        >
          <span className="leading-snug">{question}</span>
          <ChevronDown
            className={cn(
              'w-4 h-4 text-text-muted shrink-0 transition-transform duration-200 ease-smooth',
              isOpen && 'rotate-180 text-cerelo-orange'
            )}
            aria-hidden="true"
          />
        </button>
      </h3>

      {/* CSS-transition panel — no visibility:hidden flash, respects reduced-motion via globals.css */}
      <div
        id={`faq-answer-${id}`}
        role="region"
        aria-labelledby={`faq-question-${id}`}
        style={{ maxHeight: isOpen ? `${contentHeight}px` : '0px' }}
        className="overflow-hidden transition-all duration-200 ease-smooth"
      >
        <div
          ref={contentRef}
          className="px-5 pb-5 pt-2 border-t border-border/50"
        >
          <p className="text-body text-text-secondary leading-relaxed">{answer}</p>
        </div>
      </div>
    </div>
  );
}
