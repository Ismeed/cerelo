import type { Metadata } from 'next';
import { Mail, Phone, Clock, MapPin, ShieldCheck } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { ContactForm } from '@/components/ui/ContactForm';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { SITE_CONFIG } from '@/lib/config/site';
import { CORRIDOR_DATA } from '@/lib/data/corridor';

export const metadata: Metadata = {
  title: 'Contact CERELO',
  description:
    'Contact CERELO for parcel shipment support, merchant pickup arrangements, and corridor operations questions on the Kano ↔ Katsina route.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/contact`,
  },
};

export default function ContactPage() {
  const { contact } = SITE_CONFIG;

  return (
    <div className="py-10 sm:py-16 space-y-12">
      <Container size="content">
        <div className="space-y-4 text-center">
          <div className="flex justify-center items-center gap-2">
            <Badge variant="orange">Operations &amp; Support</Badge>
            <CorridorBadge size="sm" />
          </div>
          <h1 className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight max-w-2xl mx-auto">
            Contact CERELO Operations
          </h1>
          <p className="text-base sm:text-lg text-text-secondary max-w-xl mx-auto leading-relaxed">
            Have questions about an active shipment, merchant pickups, or corridor operations between Kano and Katsina? Connect directly with our team.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 mt-12 max-w-5xl mx-auto">
          {/* ── 1. Direct Channels & Hub Info Column ─────────────────── */}
          <div className="space-y-6">
            <div className="bg-surface-white p-6 sm:p-8 rounded-2xl border border-border space-y-6 shadow-subtle">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-4">
                Direct Operational Channels
              </h2>

              <div className="space-y-5">
                {/* Phone — only renders when non-null */}
                {contact.phone && (
                  <div className="flex items-start gap-4">
                    <div className="p-3 bg-cerelo-navy/5 text-cerelo-orange rounded-xl shrink-0">
                      <Phone className="w-5 h-5" aria-hidden="true" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-cerelo-navy">Operations Hotline</h3>
                      <p className="text-xs text-text-muted mb-1">For active shipment questions</p>
                      <a
                        href={`tel:${contact.phone}`}
                        className="text-base font-bold text-cerelo-navy hover:text-cerelo-orange transition-colors"
                      >
                        {contact.phone}
                      </a>
                    </div>
                  </div>
                )}

                {/* Email — only renders when non-null */}
                {contact.email && (
                  <div className={`flex items-start gap-4 ${contact.phone ? 'pt-4 border-t border-border' : ''}`}>
                    <div className="p-3 bg-cerelo-navy/5 text-cerelo-orange rounded-xl shrink-0">
                      <Mail className="w-5 h-5" aria-hidden="true" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-cerelo-navy">Support Email</h3>
                      <p className="text-xs text-text-muted mb-1">For general &amp; business inquiries</p>
                      <a
                        href={`mailto:${contact.email}`}
                        className="text-sm font-bold text-cerelo-navy hover:text-cerelo-orange transition-colors"
                      >
                        {contact.email}
                      </a>
                    </div>
                  </div>
                )}

                {/* Hours — only renders when non-null */}
                {contact.operatingDays && contact.hours && (
                  <div className="flex items-start gap-4 pt-4 border-t border-border">
                    <div className="p-3 bg-cerelo-navy/5 text-cerelo-orange rounded-xl shrink-0">
                      <Clock className="w-5 h-5" aria-hidden="true" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-cerelo-navy">Support Desk Hours</h3>
                      <p className="text-sm text-text-secondary mt-0.5 font-medium">{contact.operatingDays}</p>
                      <p className="text-xs text-text-muted">{contact.hours}</p>
                    </div>
                  </div>
                )}

                {/* Fallback when direct support channels are pending */}
                {!contact.phone && !contact.email && !contact.operatingDays && (
                  <div className="space-y-3">
                    <p className="text-xs text-text-secondary leading-relaxed">
                      Public support telephone and email channels are currently being finalized for launch.
                    </p>
                    <div className="p-3.5 rounded-lg bg-surface-subtle border border-border text-xs text-text-secondary">
                      <strong>Active delivery questions?</strong> Track your shipment milestones directly using your Delivery Code.
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Operating Hub Cities */}
            <div className="bg-surface-subtle p-6 rounded-2xl border border-border space-y-4">
              <div className="flex items-center gap-2 font-bold text-sm text-cerelo-navy">
                <MapPin className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Corridor Operating Cities</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs text-text-secondary">
                <div className="p-4 bg-surface-white rounded-xl border border-border">
                  <strong className="block text-cerelo-navy mb-1 text-sm">
                    {CORRIDOR_DATA.origin.name}
                  </strong>
                  <span className="text-text-muted font-medium">{CORRIDOR_DATA.origin.state}</span>
                </div>
                <div className="p-4 bg-surface-white rounded-xl border border-border">
                  <strong className="block text-cerelo-navy mb-1 text-sm">
                    {CORRIDOR_DATA.destination.name}
                  </strong>
                  <span className="text-text-muted font-medium">{CORRIDOR_DATA.destination.state}</span>
                </div>
              </div>
              <div className="flex items-center gap-1.5 text-[11px] text-text-muted pt-1">
                <ShieldCheck className="w-3.5 h-3.5 text-cerelo-orange shrink-0" aria-hidden="true" />
                <span>Operating exclusively on the Kano ↔ Katsina corridor.</span>
              </div>
            </div>
          </div>

          {/* ── 2. Contact Form Column ─────────────────────────────────── */}
          <div className="bg-surface-white p-6 sm:p-8 rounded-2xl border border-border space-y-6 shadow-subtle">
            <div className="space-y-1.5 border-b border-border pb-4">
              <h2 className="text-xl font-bold text-cerelo-navy">Send an Operational Inquiry</h2>
              <p className="text-xs text-text-secondary">
                Submit an inquiry to our operations team and we will respond promptly.
              </p>
            </div>
            <ContactForm />
          </div>
        </div>
      </Container>
    </div>
  );
}
