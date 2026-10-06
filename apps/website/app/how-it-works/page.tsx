import type { Metadata } from 'next';
import { ArrowRight, CreditCard, ShieldCheck, CheckCircle2, Clock, XCircle } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card } from '@/components/ui/Card';
import { StatusTimeline } from '@/components/ui/StatusTimeline';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { SITE_CONFIG } from '@/lib/config/site';

export const metadata: Metadata = {
  title: 'How CERELO Works | Door-to-Door Intercity Delivery',
  description:
    'Understand how CERELO manages door-to-door parcel delivery on the Kano ↔ Katsina corridor — from doorstep pickup and hub processing to middle-mile transit and doorstep delivery.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/how-it-works`,
  },
};

const DETAILED_JOURNEY_STEPS = [
  {
    step: 1,
    title: 'Request Your Shipment',
    actor: 'Sender on CERELO App',
    description:
      'Enter pickup address, receiver details, parcel description, and select who pays. Your request is queued for personnel dispatch.',
    badge: 'Step 01',
  },
  {
    step: 2,
    title: 'CERELO Personnel Pickup',
    actor: 'Authorized CERELO Personnel',
    description:
      'Personnel arrives at your doorstep, inspects package integrity, confirms size tier, accepts custody, and issues your unique Delivery Code.',
    badge: 'Step 02',
  },
  {
    step: 3,
    title: 'Origin Hub Consolidation',
    actor: 'Origin Hub Operations',
    description:
      'Your parcel is received at the origin operating hub, logged into the operational ledger, and staged into a sealed corridor batch.',
    badge: 'Step 03',
  },
  {
    step: 4,
    title: 'Intercity Corridor Transit',
    actor: 'Middle-Mile Transit',
    description:
      'The sealed batch moves across the Kano ↔ Katsina highway under manifest tracking until arrival at the target city.',
    badge: 'Step 04',
  },
  {
    step: 5,
    title: 'Destination Hub Reconciliation',
    actor: 'Destination Hub Operations',
    description:
      'Destination personnel unpacks the transit batch, verifies package identity against the manifest, and assigns it for final-mile route.',
    badge: 'Step 05',
  },
  {
    step: 6,
    title: 'Out for Doorstep Delivery',
    actor: 'Delivery Personnel',
    description:
      'Authorized Personnel takes custody of your parcel and proceeds directly to the recipient’s address in the destination city.',
    badge: 'Step 06',
  },
  {
    step: 7,
    title: 'Doorstep Delivery Completion',
    actor: 'Recipient Handover',
    description:
      'Parcel is handed over to the receiver. Payment is collected if Receiver Pays, and completion is recorded in the ledger.',
    badge: 'Step 07',
  },
] as const;

export default function HowItWorksPage() {
  return (
    <div className="space-y-0">
      {/* ── 1. Page Hero ────────────────────────────────────────────── */}
      <Section variant="white" labelledBy="page-title">
        <Container size="content">
          <div className="space-y-5 text-center">
            <div className="flex justify-center items-center gap-2">
              <Badge variant="orange">Door-to-Door Process</Badge>
              <CorridorBadge size="sm" />
            </div>
            <h1 id="page-title" className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight max-w-3xl mx-auto">
              From Request to Doorstep — One Coordinated Journey
            </h1>
            <p className="text-base sm:text-lg text-text-secondary max-w-2xl mx-auto leading-relaxed">
              CERELO manages every handoff between Kano and Katsina. From the moment you request a pickup until the receiver receives their parcel, your shipment is tracked and in authorized custody.
            </p>
            <div className="pt-2 flex flex-wrap items-center justify-center gap-3">
              <Button href={SITE_CONFIG.ctaDestinations.sendPackage.href} size="lg">
                <span>{SITE_CONFIG.ctaDestinations.sendPackage.label}</span>
                <ArrowRight className="w-4 h-4" aria-hidden="true" />
              </Button>
              <Button href={SITE_CONFIG.ctaDestinations.trackShipment.href} variant="outline" size="lg">
                {SITE_CONFIG.ctaDestinations.trackShipment.label}
              </Button>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 2. 7-Stage Detailed Customer Journey ─────────────────── */}
      <Section variant="subtle" labelledBy="journey-heading" id="lifecycle">
        <Container size="content">
          <SectionHeader
            eyebrow="Complete Chain of Custody"
            title="The 7 Verified Parcel Lifecycle Stages"
            titleId="journey-heading"
            description="Every transition in the CERELO network requires physical authorization and is recorded in an immutable operational ledger."
            align="center"
            className="mb-12 max-w-2xl mx-auto"
          />

          {/* Desktop/Tablet visual progression grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {DETAILED_JOURNEY_STEPS.map((item) => (
              <Card
                key={item.step}
                className="relative space-y-3 bg-surface-white border border-border p-6 hover:border-cerelo-navy/40 hover:shadow-card transition-all duration-200"
              >
                <div className="flex items-center justify-between">
                  <span className="text-[11px] font-bold text-cerelo-orange uppercase tracking-wider bg-cerelo-orange-soft px-2.5 py-1 rounded-full">
                    {item.badge}
                  </span>
                  <span className="text-xs font-semibold text-text-muted">
                    {item.actor}
                  </span>
                </div>
                <h3 className="text-base font-bold text-cerelo-navy">{item.title}</h3>
                <p className="text-xs text-text-secondary leading-relaxed">
                  {item.description}
                </p>
              </Card>
            ))}

            {/* Stage Summary Card */}
            <div className="rounded-xl bg-cerelo-navy text-white p-6 flex flex-col justify-between space-y-4">
              <div className="space-y-2">
                <Badge variant="orange">Verified Ledger</Badge>
                <h3 className="text-lg font-bold text-white">Status-Based Transparency</h3>
                <p className="text-xs text-white/75 leading-relaxed">
                  You can track your Delivery Code through every one of these 7 verified custody milestones on our tracking portal.
                </p>
              </div>
              <Button href="/track" variant="white" size="sm" className="self-start">
                Track a Shipment Code
              </Button>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 3. Interactive Status Timeline Sample ─────────────────── */}
      <Section variant="white" tight labelledBy="timeline-sample-heading">
        <Container size="content">
          <div className="bg-surface-white p-6 sm:p-10 rounded-2xl border border-border space-y-6 shadow-subtle max-w-4xl mx-auto">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-6">
              <div>
                <h2 id="timeline-sample-heading" className="text-xl font-bold text-cerelo-navy">
                  How Milestone Tracking Appears
                </h2>
                <p className="text-xs text-text-secondary mt-1">
                  Verified stage updates show what has actually happened with your package.
                </p>
              </div>
              <CorridorBadge size="sm" />
            </div>

            <StatusTimeline currentStageKey="IN_TRANSIT" />
          </div>
        </Container>
      </Section>

      {/* ── 4. Payment Modes Explanation ──────────────────────────── */}
      <Section variant="subtle" labelledBy="payments-heading" id="payments">
        <Container size="content">
          <SectionHeader
            eyebrow="Payment Flexibility"
            title="Three Clear Payment Responsibility Options"
            titleId="payments-heading"
            description="Select who pays the delivery fee during shipment creation. Physical cash payments are collected and recorded by CERELO Personnel."
            align="center"
            className="mb-10 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="w-10 h-10 rounded-lg bg-cerelo-navy/5 text-cerelo-navy flex items-center justify-center font-bold">
                <CreditCard className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Sender Pays</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                The sender pays the full delivery fee directly to CERELO Personnel at the point of doorstep collection in the origin city.
              </p>
            </Card>

            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="w-10 h-10 rounded-lg bg-cerelo-navy/5 text-cerelo-navy flex items-center justify-center font-bold">
                <CreditCard className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Receiver Pays</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                Ideal for e-commerce and merchants. The recipient pays the delivery fee upon doorstep handover in the destination city.
              </p>
            </Card>

            <Card hoverable className="space-y-3 bg-surface-white p-6">
              <div className="w-10 h-10 rounded-lg bg-cerelo-navy/5 text-cerelo-navy flex items-center justify-center font-bold">
                <CreditCard className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Split Payment</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                The delivery cost is divided between sender and receiver, collected at pickup and doorstep delivery respectively.
              </p>
            </Card>
          </div>

          <div className="mt-8 max-w-2xl mx-auto p-4 bg-surface-white rounded-xl border border-border text-xs text-text-secondary text-center leading-relaxed">
            <strong>Payment Recording Note:</strong> All payments are physically verified by authorized Personnel and immediately updated in the shipment ledger.
          </div>
        </Container>
      </Section>

      {/* ── 5. Cancellation Lifecycle Rules ───────────────────────── */}
      <Section variant="white" labelledBy="cancellation-heading" id="cancellation">
        <Container size="content">
          <SectionHeader
            eyebrow="Customer Control"
            title="Shipment Cancellation Rights & Rules"
            titleId="cancellation-heading"
            description="We provide clear, customer-controlled cancellation rights balanced with middle-mile operational safety."
            align="center"
            className="mb-10 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl mx-auto">
            {/* Stage 1 */}
            <Card className="border-status-success/40 bg-status-success-bg/20 space-y-3 p-6">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-status-success uppercase tracking-wider">
                  Phase 1: Requested
                </span>
                <CheckCircle2 className="w-4 h-4 text-status-success" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Cancel Request</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                Before personnel arrives for pickup, you can tap &ldquo;Cancel Request&rdquo; directly in the customer app to cancel immediately with zero penalty.
              </p>
            </Card>

            {/* Stage 2 */}
            <Card className="border-cerelo-orange/40 bg-cerelo-orange-soft/40 space-y-3 p-6">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-cerelo-orange uppercase tracking-wider">
                  Phase 2: At Origin Hub
                </span>
                <Clock className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Cancel Delivery</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                After pickup but while the parcel is staged at the origin hub, you can request &ldquo;Cancel Delivery&rdquo; to coordinate parcel return from the hub.
              </p>
            </Card>

            {/* Stage 3 */}
            <Card className="border-border bg-surface-subtle space-y-3 p-6">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-text-muted uppercase tracking-wider">
                  Phase 3: In Transit
                </span>
                <XCircle className="w-4 h-4 text-text-muted" aria-hidden="true" />
              </div>
              <h3 className="text-base font-bold text-cerelo-navy">Transit Cutoff</h3>
              <p className="text-xs text-text-secondary leading-relaxed">
                Once sealed batches enter <strong className="text-cerelo-navy">In Transit</strong> on the intercity corridor, self-cancellation closes to protect batch manifest security.
              </p>
            </Card>
          </div>
        </Container>
      </Section>

      {/* ── 6. Milestone vs Live GPS Tracking Explanation ────────── */}
      <Section variant="navy" labelledBy="tracking-exp-heading">
        <Container size="content">
          <div className="max-w-3xl mx-auto space-y-6 text-center">
            <Badge variant="orange">Status-Based Transparency</Badge>
            <h2 id="tracking-exp-heading" className="text-2xl sm:text-3xl font-black text-white">
              Authentic Milestone Tracking — No Simulated GPS
            </h2>
            <p className="text-sm sm:text-base text-white/75 leading-relaxed">
              CERELO updates parcel status at physical custody handoffs. We don&apos;t show fake moving car icons on a map — you see verified operational milestones that reflect actual custody transfers.
            </p>
            <div className="p-4 rounded-xl bg-white/10 border border-white/15 text-xs text-white/80 max-w-xl mx-auto flex items-center justify-center gap-2">
              <ShieldCheck className="w-4 h-4 text-cerelo-orange-light shrink-0" aria-hidden="true" />
              <span>Public tracking links display only masked names and city-level routing for customer privacy.</span>
            </div>
            <div className="pt-2">
              <Button href={SITE_CONFIG.ctaDestinations.trackShipment.href} variant="white" size="lg">
                Track a Delivery Code Now
              </Button>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 7. Page Closing CTA ─────────────────────────────────────── */}
      <Section variant="white">
        <Container size="content">
          <div id="get-started" className="bg-cerelo-navy text-white p-8 sm:p-12 rounded-2xl text-center space-y-6 max-w-4xl mx-auto shadow-card">
            <h2 className="text-2xl sm:text-3xl font-black text-white">
              Ready to Send Between Kano &amp; Katsina?
            </h2>
            <p className="text-sm text-text-inverse/75 max-w-lg mx-auto leading-relaxed">
              Request doorstep pickup via the CERELO app and let authorized personnel handle the intercity journey.
            </p>
            <div className="flex flex-wrap items-center justify-center gap-3">
              <Button href={SITE_CONFIG.ctaDestinations.sendPackage.href} size="lg">
                <span>{SITE_CONFIG.ctaDestinations.sendPackage.label}</span>
                <ArrowRight className="w-4 h-4" aria-hidden="true" />
              </Button>
              <Button href="/contact" variant="outline" size="lg" className="text-white border-white/40 hover:bg-white/10 hover:text-white">
                Contact Operations
              </Button>
            </div>
          </div>
        </Container>
      </Section>
    </div>
  );
}
