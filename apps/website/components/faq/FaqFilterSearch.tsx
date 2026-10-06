'use client';

import { useState, useMemo } from 'react';
import { Search, X } from 'lucide-react';
import { AccordionItem } from '@/components/ui/Accordion';
import { FAQ_CATEGORIES, type FAQCategory, type FAQItem } from '@/lib/data/faq';
import { cn } from '@/lib/utils';

export function FaqFilterSearch() {
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // Filter categories and items based on search query and active tab
  const filteredCategories = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();

    return FAQ_CATEGORIES.map((category: FAQCategory) => {
      // If category tab selected and doesn't match, skip
      if (selectedCategory !== 'all' && category.id !== selectedCategory) {
        return null;
      }

      // Filter items in category matching query
      const matchingItems = category.items.filter((item: FAQItem) => {
        if (!query) return true;
        return (
          item.question.toLowerCase().includes(query) ||
          item.answer.toLowerCase().includes(query)
        );
      });

      if (matchingItems.length === 0) return null;

      return {
        ...category,
        items: matchingItems,
      };
    }).filter((cat): cat is FAQCategory => cat !== null);
  }, [selectedCategory, searchQuery]);

  const totalResults = useMemo(() => {
    return filteredCategories.reduce((acc, cat) => acc + cat.items.length, 0);
  }, [filteredCategories]);

  return (
    <div className="space-y-8">
      {/* ── Search Bar & Category Filter Tabs ────────────────────────── */}
      <div className="space-y-4 max-w-2xl mx-auto">
        {/* Search input */}
        <div className="relative">
          <Search
            className="w-4 h-4 text-text-muted absolute left-4 top-1/2 -translate-y-1/2"
            aria-hidden="true"
          />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search questions (e.g., tracking, payment, cancellation)..."
            className={cn(
              'w-full pl-11 pr-10 py-3 text-sm rounded-xl border border-border bg-surface-white',
              'placeholder:text-text-muted text-text-primary',
              'focus:outline-none focus:ring-2 focus:ring-cerelo-orange focus:border-transparent',
              'transition-all duration-150 shadow-subtle'
            )}
            aria-label="Search frequently asked questions"
          />
          {searchQuery && (
            <button
              type="button"
              onClick={() => setSearchQuery('')}
              className="absolute right-3.5 top-1/2 -translate-y-1/2 p-1 text-text-muted hover:text-text-primary rounded-md"
              aria-label="Clear search query"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Category tabs */}
        <div
          className="flex flex-wrap items-center justify-center gap-2 pt-2"
          role="tablist"
          aria-label="FAQ categories"
        >
          <button
            type="button"
            role="tab"
            aria-selected={selectedCategory === 'all'}
            onClick={() => setSelectedCategory('all')}
            className={cn(
              'px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-150',
              selectedCategory === 'all'
                ? 'bg-cerelo-navy text-white shadow-subtle'
                : 'bg-surface-subtle text-text-secondary hover:bg-border hover:text-text-primary'
            )}
          >
            All Questions
          </button>
          {FAQ_CATEGORIES.map((cat: FAQCategory) => (
            <button
              key={cat.id}
              type="button"
              role="tab"
              aria-selected={selectedCategory === cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={cn(
                'px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all duration-150',
                selectedCategory === cat.id
                  ? 'bg-cerelo-navy text-white shadow-subtle'
                  : 'bg-surface-subtle text-text-secondary hover:bg-border hover:text-text-primary'
              )}
            >
              {cat.title}
            </button>
          ))}
        </div>
      </div>

      {/* ── Active Search/Filter Results Summary ────────────────────── */}
      {(searchQuery || selectedCategory !== 'all') && (
        <div className="flex items-center justify-between text-xs text-text-secondary border-b border-border pb-3">
          <span>
            Showing <strong>{totalResults}</strong> result{totalResults === 1 ? '' : 's'}
            {searchQuery && <> for &ldquo;<strong>{searchQuery}</strong>&rdquo;</>}
          </span>
          <button
            type="button"
            onClick={() => {
              setSearchQuery('');
              setSelectedCategory('all');
            }}
            className="text-cerelo-orange font-semibold hover:underline"
          >
            Reset Filters
          </button>
        </div>
      )}

      {/* ── Categorized Accordions ─────────────────────────────────── */}
      {filteredCategories.length > 0 ? (
        <div className="space-y-10">
          {filteredCategories.map((category: FAQCategory) => (
            <section
              key={category.id}
              id={category.id}
              aria-labelledby={`category-title-${category.id}`}
              className="space-y-4"
            >
              <div className="border-b border-border pb-3">
                <h2
                  id={`category-title-${category.id}`}
                  className="text-lg sm:text-xl font-bold text-cerelo-navy"
                >
                  {category.title}
                </h2>
                <p className="text-xs text-text-secondary mt-0.5">
                  {category.description}
                </p>
              </div>

              <div className="space-y-3">
                {category.items.map((item: FAQItem) => (
                  <AccordionItem
                    key={item.id}
                    id={item.id}
                    question={item.question}
                    answer={item.answer}
                  />
                ))}
              </div>
            </section>
          ))}
        </div>
      ) : (
        <div className="py-12 text-center space-y-3 bg-surface-white rounded-xl border border-border">
          <p className="text-sm font-semibold text-text-primary">No questions found</p>
          <p className="text-xs text-text-secondary max-w-sm mx-auto">
            We couldn&apos;t find any questions matching your search query &ldquo;{searchQuery}&rdquo;.
          </p>
          <button
            type="button"
            onClick={() => {
              setSearchQuery('');
              setSelectedCategory('all');
            }}
            className="text-xs font-bold text-cerelo-orange hover:underline pt-1"
          >
            Clear Search & View All
          </button>
        </div>
      )}
    </div>
  );
}
