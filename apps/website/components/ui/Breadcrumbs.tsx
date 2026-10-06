import Link from 'next/link';
import { ChevronRight, Home } from 'lucide-react';
import { Container } from './Container';

export interface BreadcrumbItem {
  label: string;
  href?: string;
}

export interface BreadcrumbsProps {
  items: BreadcrumbItem[];
}

export function Breadcrumbs({ items }: BreadcrumbsProps) {
  return (
    <nav aria-label="Breadcrumb" className="py-3 border-b border-border/60 bg-surface-white/60">
      <Container>
        <ol className="flex items-center space-x-2 text-xs text-text-muted">
          <li>
            <Link
              href="/"
              className="flex items-center gap-1 hover:text-cerelo-navy transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cerelo-orange rounded"
            >
              <Home className="w-3.5 h-3.5" aria-hidden="true" />
              <span className="sr-only">Home</span>
            </Link>
          </li>
          {items.map((item, index) => {
            const isLast = index === items.length - 1;
            return (
              <li key={index} className="flex items-center space-x-2">
                <ChevronRight className="w-3 h-3 text-border-strong shrink-0" aria-hidden="true" />
                {isLast || !item.href ? (
                  <span className="font-medium text-cerelo-navy truncate max-w-[200px]" aria-current="page">
                    {item.label}
                  </span>
                ) : (
                  <Link
                    href={item.href}
                    className="hover:text-cerelo-navy transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cerelo-orange rounded"
                  >
                    {item.label}
                  </Link>
                )}
              </li>
            );
          })}
        </ol>
      </Container>
    </nav>
  );
}
