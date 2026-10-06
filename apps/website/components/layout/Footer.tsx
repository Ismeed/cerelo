import Link from 'next/link';
import Image from 'next/image';
import { Mail, Phone, Clock } from 'lucide-react';
import { SITE_CONFIG } from '@/lib/config/site';
import { FOOTER_NAV } from '@/lib/config/navigation';
import { Container } from '@/components/ui/Container';
import { CorridorBadge } from '@/components/ui/CorridorBadge';

export function Footer() {
  const { contact } = SITE_CONFIG;
  const hasEmail = Boolean(contact.email);
  const hasPhone = Boolean(contact.phone);
  const hasHours = Boolean(contact.operatingDays && contact.hours);
  const hasAnyContact = hasEmail || hasPhone || hasHours;

  return (
    <footer className="bg-cerelo-navy-deep text-white border-t border-border-dark mt-auto">
      {/* Corridor Identity Banner */}
      <div className="border-b border-border-dark/60 bg-cerelo-navy py-3.5">
        <Container>
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <CorridorBadge inverted size="md" />
            <p className="text-xs text-text-muted">
              Intercity door-to-door parcel delivery — both directions served.
            </p>
          </div>
        </Container>
      </div>

      <Container className="py-12 sm:py-16">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-10 lg:gap-8">
          {/* Col 1 & 2: Brand Block */}
          <div className="lg:col-span-2 space-y-4">
            {/* Wordmark */}
            <div className="flex items-center gap-3">
              <div className="relative w-10 h-10 rounded-lg overflow-hidden border border-border-dark shadow-subtle">
                <Image
                  src="/images/cerelo-badge-dark.jpg"
                  alt="CERELO Logistics"
                  fill
                  sizes="40px"
                  className="object-cover"
                />
              </div>
              <div className="flex flex-col leading-none">
                <span className="text-2xl font-black tracking-tight text-white">
                  {SITE_CONFIG.name}
                </span>
                <span className="text-[10px] uppercase font-semibold text-text-muted mt-0.5 tracking-wider">
                  Intercity Logistics Network
                </span>
              </div>
            </div>

            <p className="text-sm text-text-muted max-w-sm leading-relaxed">
              {SITE_CONFIG.description}
            </p>

            {/* Contact block — only renders when values are non-null */}
            {hasAnyContact && (
              <div className="pt-1 space-y-2 text-xs text-text-muted">
                {hasEmail && (
                  <div className="flex items-center gap-2">
                    <Mail className="w-3.5 h-3.5 text-cerelo-orange shrink-0" aria-hidden="true" />
                    <a
                      href={`mailto:${contact.email}`}
                      className="hover:text-white transition-colors duration-150"
                    >
                      {contact.email}
                    </a>
                  </div>
                )}
                {hasPhone && (
                  <div className="flex items-center gap-2">
                    <Phone className="w-3.5 h-3.5 text-cerelo-orange shrink-0" aria-hidden="true" />
                    <a
                      href={`tel:${contact.phone}`}
                      className="hover:text-white transition-colors duration-150"
                    >
                      {contact.phone}
                    </a>
                  </div>
                )}
                {hasHours && (
                  <div className="flex items-center gap-2">
                    <Clock className="w-3.5 h-3.5 text-cerelo-orange shrink-0" aria-hidden="true" />
                    <span>
                      {contact.operatingDays}: {contact.hours}
                    </span>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Col 3: Service Links */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-white">
              Service
            </h3>
            <ul className="space-y-2.5 text-sm">
              {FOOTER_NAV.service.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-text-muted hover:text-white transition-colors duration-150"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Col 4: Company Links */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-white">
              Company
            </h3>
            <ul className="space-y-2.5 text-sm">
              {FOOTER_NAV.company.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-text-muted hover:text-white transition-colors duration-150"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Col 5: Legal */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-white">
              Legal
            </h3>
            <ul className="space-y-2.5 text-sm">
              {FOOTER_NAV.legal.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-text-muted hover:text-white transition-colors duration-150"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-10 mt-10 border-t border-border-dark/60 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-text-muted">
          <p>
            &copy; {new Date().getFullYear()} CERELO. All rights reserved.
          </p>
          <p className="text-[11px]">
            Operating exclusively on the {SITE_CONFIG.corridor.name}.
          </p>
        </div>
      </Container>
    </footer>
  );
}
