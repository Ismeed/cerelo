'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { Menu, X, ArrowRight } from 'lucide-react';
import { PRIMARY_NAV_ITEMS, MOBILE_NAV_ITEMS, isActiveRoute } from '@/lib/config/navigation';
import { SITE_CONFIG } from '@/lib/config/site';
import { Container } from '@/components/ui/Container';
import { Button } from '@/components/ui/Button';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { cn } from '@/lib/utils';

export function Header() {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isScrolled, setIsScrolled] = useState(false);
  const pathname = usePathname();

  // Escape key dismisses mobile drawer
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isMobileMenuOpen) {
        setIsMobileMenuOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isMobileMenuOpen]);

  // Body scroll lock when drawer is open
  useEffect(() => {
    document.body.style.overflow = isMobileMenuOpen ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [isMobileMenuOpen]);

  // Shadow on scroll
  useEffect(() => {
    const handleScroll = () => setIsScrolled(window.scrollY > 4);
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <>
      <header
        className={cn(
          'sticky top-0 z-40 bg-white/97 backdrop-blur-md border-b border-border',
          'transition-shadow duration-200',
          isScrolled && 'shadow-header'
        )}
      >
        <Container>
          <div className="flex items-center justify-between h-16 sm:h-18">
            {/* Brand Logo */}
            <Link
              href="/"
              className="flex items-center gap-3 group focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cerelo-orange rounded-md"
              aria-label="CERELO Home"
            >
              <div className="relative w-9 h-9 sm:w-10 sm:h-10 rounded-lg overflow-hidden border border-border shadow-subtle group-hover:scale-105 transition-transform duration-150">
                <Image
                  src="/images/cerelo-badge-light.png"
                  alt="CERELO Logistics"
                  fill
                  sizes="40px"
                  className="object-cover"
                  priority
                />
              </div>
              <div className="flex flex-col leading-none">
                <span className="text-xl sm:text-2xl font-black tracking-tight text-cerelo-navy">
                  CERELO
                </span>
                <span className="text-[10px] tracking-wider uppercase font-semibold text-text-muted hidden sm:block mt-0.5">
                  Intercity Logistics
                </span>
              </div>
            </Link>

            {/* Desktop Navigation */}
            <nav aria-label="Main Navigation" className="hidden md:flex items-center gap-0.5 lg:gap-1">
              {PRIMARY_NAV_ITEMS.map((item) => {
                const active = isActiveRoute(pathname, item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={cn(
                      'px-3 py-2 text-sm font-medium rounded-md transition-colors duration-150',
                      active
                        ? 'text-cerelo-navy font-semibold bg-surface-subtle'
                        : 'text-text-secondary hover:text-cerelo-navy hover:bg-surface-subtle'
                    )}
                    aria-current={active ? 'page' : undefined}
                  >
                    {item.label}
                  </Link>
                );
              })}
            </nav>

            {/* Desktop CTAs */}
            <div className="hidden md:flex items-center gap-2.5">
              <Button
                href={SITE_CONFIG.ctaDestinations.trackShipment.href}
                variant="outline"
                size="sm"
              >
                Track Shipment
              </Button>
              <Button
                href={SITE_CONFIG.ctaDestinations.sendPackage.href}
                variant="primary"
                size="sm"
              >
                <span>Send a Package</span>
                <ArrowRight className="w-3.5 h-3.5" aria-hidden="true" />
              </Button>
            </div>

            {/* Mobile Controls */}
            <div className="flex md:hidden items-center gap-2">
              <Button
                href={SITE_CONFIG.ctaDestinations.trackShipment.href}
                variant="outline"
                size="sm"
                className="text-xs px-2.5 h-8"
              >
                Track
              </Button>
              <button
                type="button"
                onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                className="p-2 rounded-md text-text-secondary hover:text-cerelo-navy hover:bg-surface-subtle focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cerelo-orange transition-colors"
                aria-expanded={isMobileMenuOpen}
                aria-controls="mobile-navigation-drawer"
                aria-label={isMobileMenuOpen ? 'Close navigation menu' : 'Open navigation menu'}
              >
                {isMobileMenuOpen ? (
                  <X className="w-5 h-5" aria-hidden="true" />
                ) : (
                  <Menu className="w-5 h-5" aria-hidden="true" />
                )}
              </button>
            </div>
          </div>
        </Container>

        {/* Mobile Navigation Drawer */}
        {isMobileMenuOpen && (
          <div
            id="mobile-navigation-drawer"
            className="md:hidden border-t border-border bg-white max-h-[calc(100dvh-4rem)] overflow-y-auto"
          >
            <Container className="py-4 space-y-4">
              <nav aria-label="Mobile Navigation" className="flex flex-col space-y-0.5">
                {MOBILE_NAV_ITEMS.map((item) => {
                  const active = isActiveRoute(pathname, item.href);
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      onClick={() => setIsMobileMenuOpen(false)}
                      className={cn(
                        'px-3 py-3 text-base font-medium rounded-md transition-colors flex items-center justify-between',
                        active
                          ? 'text-cerelo-navy font-semibold bg-surface-subtle'
                          : 'text-text-secondary hover:text-cerelo-navy hover:bg-surface-subtle'
                      )}
                      aria-current={active ? 'page' : undefined}
                    >
                      <span>{item.label}</span>
                      {active && <span className="w-1.5 h-1.5 rounded-full bg-cerelo-orange" aria-hidden="true" />}
                    </Link>
                  );
                })}
              </nav>

              <div className="pt-3 border-t border-border space-y-2">
                <Button
                  href={SITE_CONFIG.ctaDestinations.sendPackage.href}
                  variant="primary"
                  size="md"
                  className="w-full justify-center"
                  onClick={() => setIsMobileMenuOpen(false)}
                >
                  <span>Send a Package</span>
                  <ArrowRight className="w-4 h-4" aria-hidden="true" />
                </Button>
                <div className="flex justify-center pt-1">
                  <CorridorBadge size="sm" />
                </div>
              </div>
            </Container>
          </div>
        )}
      </header>
    </>
  );
}
