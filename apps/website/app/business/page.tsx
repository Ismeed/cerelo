import type { Metadata } from 'next';
import { ArrowRight, Store, Truck, ShieldCheck, Mail, Phone, CheckCircle2, Share2 } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card } from '@/components/ui/Card';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { SITE_CONFIG } from '@/lib/config/site';

export const metadata: Metadata = {
  title: 'CERELO for Business | Kano ↔ Katsina Delivery',
  description:
    'Streamline Kano ↔ Katsina parcel delivery for your business. CERELO handles store pickup, intercity corridor transit, and doorstep delivery for online sellers, market traders, and wholesalers.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/business`,
  },
};

const MERCHANT_PAIN_POINTS = [
  {
    title: 'No More Motor Park Trips',
    description: 'Stop sending staff or leaving your shop to navigate busy motor parks and negotiate unpredictable driver rates.',
  },
  {
    title: 'Protected Buyer Relationships',
    description: 'Eliminate situations where buyers have to travel to distant destination parks to find their orders.',
  },
  {
    title: 'Fewer Inquiry Calls',
    description: 'Stop fielding repetitive &ldquo;where is my order?&rdquo; phone calls by sharing verified stage tracking links with buyers.',
  },
] as const;

const BUSINESS_USE_CASES = [
  {
    role: 'Social Commerce & Online Sellers',
    scenario: 'You sell fashion, electronics, or personal items online and receive orders from buyers in Katsina or Kano.',
    solution: 'CERELO collects parcels from your location, updates tracking automatically, and delivers straight to your customer’s door.',
    badge: 'Online Merchants',
  },
  {
    role: 'Market Traders & Wholesalers',
    scenario: 'You operate a stall in commercial hubs like Kano’s Kantin Kwari or Katsina markets and ship regular customer goods.',
    solution: 'Book store pickups for multiple orders without stopping your sales operations or visiting motor parks.',
    badge: 'Wholesalers & Traders',
  },
] as const;

export default function BusinessPage() {
  const { contact } = SITE_CONFIG;

  return (
    <div className="space-y-0">
      {/* ── 1. Page Hero ────────────────────────────────────────────── */}
      <Section variant="white" labelledBy="business-hero-title">
        <Container size="content">
          <div className="space-y-5 text-center">
            <div className="flex justify-center items-center gap-2">
              <Badge variant="orange">Merchant Logistics</Badge>
              <CorridorBadge size="sm" />
            </div>
            <h1 id="business-hero-title" className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight max-w-3xl mx-auto">
              Move Customer Orders Without the Motor-Park Runaround
            </h1>
            <p className="text-base sm:text-lg text-text-secondary max-w-2xl mx-auto leading-relaxed">
              CERELO handles store pickup and doorstep delivery for traders, wholesalers, and online sellers shipping between Kano and Katsina. Focus on selling — we manage the journey.
            </p>
            <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
              <Button href={SITE_CONFIG.ctaDestinations.sendPackage.href} size="lg">
                <span>Start Sending Orders</span>
                <ArrowRight className="w-4 h-4" aria-hidden="true" />
              </Button>
              <Button href="/how-it-works" variant="outline" size="lg">
                How It Works
              </Button>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 2. Merchant Challenges (The Problem) ─────────────────── */}
      <Section variant="subtle" labelledBy="merchant-pain-heading">
        <Container size="content">
          <SectionHeader
            eyebrow="The Merchant Reality"
            title="Focus on Sales, Not Coordinating Drivers"
            titleId="merchant-pain-heading"
            description="Handling intercity shipping manually costs commercial sellers hours of lost sales time and creates customer friction."
            align="center"
            className="mb-10 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            {MERCHANT_PAIN_POINTS.map((point) => (
              <Card key={point.title} hoverable className="space-y-3 bg-surface-white p-6">
                <div className="w-9 h-9 rounded-lg bg-status-error-bg border border-status-error/20 flex items-center justify-center font-bold text-status-error text-xs" aria-hidden="true">
                  ✕
                </div>
                <h3 className="text-base font-bold text-cerelo-navy">{point.title}</h3>
                <p className="text-xs text-text-secondary leading-relaxed">
                  {point.description}
                </p>
              </Card>
            ))}
          </div>
        </Container>
      </Section>

      {/* ── 3. Business Value Pillars ─────────────────────────────── */}
      <Section variant="white" labelledBy="business-value-heading">
        <Container size="content">
          <SectionHeader
            eyebrow="The CERELO Merchant Advantage"
            title="Designed for Commercial Trade Between Kano &amp; Katsina"
            titleId="business-value-heading"
            description="Built to support the daily operational needs of market sellers, online shops, and commercial distributors."
            align="center"
            className="mb-12 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 max-w-4xl mx-auto">
            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="flex items-center gap-2 font-bold text-cerelo-navy">
                <Store className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
                <h3 className="text-base">Shop &amp; Stall Collection</h3>
              </div>
              <p className="text-xs text-text-secondary leading-relaxed">
                CERELO Personnel collects packages directly from your market stall, commercial shop, or business location.
              </p>
            </Card>

            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="flex items-center gap-2 font-bold text-cerelo-navy">
                <ShieldCheck className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
                <h3 className="text-base">Receiver Pays Delivery Option</h3>
              </div>
              <p className="text-xs text-text-secondary leading-relaxed">
                Select &ldquo;Receiver Pays&rdquo; when booking so your customers in Katsina or Kano pay their delivery fee upon doorstep handover.
              </p>
            </Card>

            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="flex items-center gap-2 font-bold text-cerelo-navy">
                <Share2 className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
                <h3 className="text-base">Shareable Buyer Tracking</h3>
              </div>
              <p className="text-xs text-text-secondary leading-relaxed">
                Send tracking links directly to your buyers so they can follow verified custody stages without calling you.
              </p>
            </Card>

            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="flex items-center gap-2 font-bold text-cerelo-navy">
                <Truck className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
                <h3 className="text-base">Consolidated Corridor Movement</h3>
              </div>
              <p className="text-xs text-text-secondary leading-relaxed">
                Parcels are consolidated at our origin hub and moved securely across the corridor with verified handover checkpoints.
              </p>
            </Card>
          </div>
        </Container>
      </Section>

      {/* ── 4. Commercial Context (Kantin Kwari & Trade Hubs) ─────── */}
      <Section variant="subtle" labelledBy="market-context-heading">
        <Container size="content">
          <div className="bg-surface-white rounded-2xl border border-border p-8 sm:p-12 space-y-6 max-w-4xl mx-auto shadow-subtle">
            <div className="space-y-2">
              <Badge variant="corridor">Commercial Corridor Context</Badge>
              <h2 id="market-context-heading" className="text-2xl font-bold text-cerelo-navy">
                Built for Northern Nigeria&apos;s Active Trade Routes
              </h2>
            </div>
            <p className="text-sm text-text-secondary leading-relaxed">
              Every day, major commercial centers like Kano&apos;s Kantin Kwari market supply goods to retailers, buyers, and online customers across Katsina State.
            </p>
            <p className="text-sm text-text-secondary leading-relaxed">
              CERELO provides a structured, trackable logistics alternative to informal motor-park arrangements, giving sellers confidence that orders will reach their recipients safely.
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
              <div className="flex items-start gap-3 p-4 rounded-xl bg-surface-subtle border border-border">
                <CheckCircle2 className="w-4 h-4 text-cerelo-orange mt-0.5 shrink-0" aria-hidden="true" />
                <div className="text-xs text-text-secondary">
                  <strong className="block text-cerelo-navy mb-0.5">Kano to Katsina Trade</strong>
                  Send textiles, merchandise, and customer retail orders directly from Kano to Katsina.
                </div>
              </div>

              <div className="flex items-start gap-3 p-4 rounded-xl bg-surface-subtle border border-border">
                <CheckCircle2 className="w-4 h-4 text-cerelo-orange mt-0.5 shrink-0" aria-hidden="true" />
                <div className="text-xs text-text-secondary">
                  <strong className="block text-cerelo-navy mb-0.5">Katsina to Kano Trade</strong>
                  Fulfill return shipments or supply customer orders moving from Katsina to Kano.
                </div>
              </div>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 5. Use-Case Scenarios ─────────────────────────────────── */}
      <Section variant="white" labelledBy="scenarios-heading">
        <Container size="content">
          <SectionHeader
            eyebrow="Merchant Use Cases"
            title="How Businesses Use CERELO Daily"
            titleId="scenarios-heading"
            align="center"
            className="mb-10 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl mx-auto">
            {BUSINESS_USE_CASES.map((useCase) => (
              <Card key={useCase.role} className="space-y-4 bg-surface-white p-6 md:p-8 border border-border">
                <span className="text-[11px] font-bold text-cerelo-navy uppercase tracking-wider bg-cerelo-navy/5 px-2.5 py-1 rounded-full inline-block">
                  {useCase.badge}
                </span>
                <h3 className="text-lg font-bold text-cerelo-navy">{useCase.role}</h3>
                <div className="space-y-2 text-xs text-text-secondary leading-relaxed">
                  <p><strong>Scenario:</strong> {useCase.scenario}</p>
                  <p><strong>CERELO Solution:</strong> {useCase.solution}</p>
                </div>
              </Card>
            ))}
          </div>
        </Container>
      </Section>

      {/* ── 6. Business Operations Contact ─────────────────────────── */}
      <Section variant="navy">
        <Container size="content">
          <div className="max-w-3xl mx-auto text-center space-y-6">
            <Badge variant="orange">Merchant Operations</Badge>
            <h2 className="text-2xl sm:text-3xl font-black text-white">
              Connect With CERELO Operations
            </h2>
            <p className="text-sm sm:text-base text-white/75 leading-relaxed max-w-lg mx-auto">
              Planning regular parcel pickups from your shop or market location between Kano and Katsina? Reach our operations desk.
            </p>

            {(contact.email || contact.phone) && (
              <div className="pt-2 flex flex-col sm:flex-row items-center justify-center gap-6 text-sm text-white/80">
                {contact.email && (
                  <div className="flex items-center gap-2">
                    <Mail className="w-4 h-4 text-cerelo-orange-light" aria-hidden="true" />
                    <a href={`mailto:${contact.email}`} className="text-white hover:underline font-semibold">
                      {contact.email}
                    </a>
                  </div>
                )}
                {contact.phone && (
                  <div className="flex items-center gap-2">
                    <Phone className="w-4 h-4 text-cerelo-orange-light" aria-hidden="true" />
                    <a href={`tel:${contact.phone}`} className="text-white hover:underline font-semibold">
                      {contact.phone}
                    </a>
                  </div>
                )}
              </div>
            )}

            <div className="pt-4 flex flex-wrap items-center justify-center gap-3">
              <Button href={SITE_CONFIG.ctaDestinations.sendPackage.href} variant="white" size="lg">
                Book Pickup via App
              </Button>
              <Button href="/contact" variant="outline" size="lg" className="text-white border-white/40 hover:bg-white/10 hover:text-white">
                Submit Inquiry
              </Button>
            </div>
          </div>
        </Container>
      </Section>
    </div>
  );
}
