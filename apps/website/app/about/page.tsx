import type { Metadata } from 'next';
import { ArrowRight, ShieldCheck, MapPin, Lock, Eye, Compass } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Section } from '@/components/ui/Section';
import { SectionHeader } from '@/components/ui/SectionHeader';
import { Card } from '@/components/ui/Card';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { SITE_CONFIG } from '@/lib/config/site';
import { CORRIDOR_DATA } from '@/lib/data/corridor';

export const metadata: Metadata = {
  title: 'About CERELO | Intercity Door-to-Door Logistics',
  description:
    'Learn about CERELO, a technology-enabled intercity logistics platform connecting Kano and Katsina with organized door-to-door parcel delivery and verified chain of custody.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/about`,
  },
};

const OPERATING_PRINCIPLES = [
  {
    title: 'Operational Integrity',
    description: 'We record only real physical custody transfers. No fake green checkmarks, no simulated GPS map icons, and no shortcutting verification.',
    icon: Lock,
  },
  {
    title: 'Corridor Discipline',
    description: 'We focus intensely on executing reliably between Kano and Katsina in both directions before expanding to new intercity trade routes.',
    icon: Compass,
  },
  {
    title: 'Customer Respect & Privacy',
    description: 'We protect customer privacy by masking public tracking links, offering clear payment options, and providing direct operational support.',
    icon: ShieldCheck,
  },
  {
    title: 'Local Context & Credibility',
    description: 'Designed specifically for the commercial realities of Northern Nigerian commerce, markets, sellers, and door-to-door deliveries.',
    icon: Eye,
  },
] as const;

export default function AboutPage() {
  return (
    <div className="space-y-0">
      {/* ── 1. Page Hero ────────────────────────────────────────────── */}
      <Section variant="white" labelledBy="about-hero-title">
        <Container size="content">
          <div className="space-y-5 text-center">
            <div className="flex justify-center items-center gap-2">
              <Badge variant="orange">Company &amp; Mission</Badge>
              <CorridorBadge size="sm" />
            </div>
            <h1 id="about-hero-title" className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight max-w-3xl mx-auto">
              Organized Intercity Door-to-Door Logistics for Northern Nigeria
            </h1>
            <p className="text-base sm:text-lg text-text-secondary max-w-2xl mx-auto leading-relaxed">
              CERELO exists to replace fragmented motor-park shipping with an organized, trackable door-to-door network where every parcel handoff is recorded.
            </p>
          </div>
        </Container>
      </Section>

      {/* ── 2. The Problem & What We Are Building ─────────────────── */}
      <Section variant="subtle" labelledBy="narrative-heading">
        <Container size="content">
          <div className="bg-surface-white p-8 sm:p-12 rounded-2xl border border-border space-y-8 max-w-4xl mx-auto shadow-subtle">
            {/* The Problem */}
            <div className="space-y-3">
              <span className="text-xs font-bold text-cerelo-orange uppercase tracking-wider">
                The Logistics Challenge
              </span>
              <h2 id="narrative-heading" className="text-2xl font-bold text-cerelo-navy">
                The Reality of Intercity Shipping
              </h2>
              <p className="text-sm text-text-secondary leading-relaxed">
                For decades, individuals and merchants sending parcels between Nigerian cities have depended on uncoordinated motor-park arrangements. Senders traveled to parks, negotiated prices informally, and handed over valuable goods without formal receipts or tracking.
              </p>
              <p className="text-sm text-text-secondary leading-relaxed">
                Recipients were forced to spend time and money traveling to destination parks, guessing arrival times, and searching for specific commercial drivers. When a parcel was delayed or lost, there was no single chain of accountability.
              </p>
            </div>

            <div className="border-t border-border pt-8 space-y-3">
              {/* What We Are Building */}
              <span className="text-xs font-bold text-cerelo-navy uppercase tracking-wider">
                Our Solution
              </span>
              <h2 className="text-2xl font-bold text-cerelo-navy">
                What CERELO Is Building
              </h2>
              <p className="text-sm text-text-secondary leading-relaxed">
                CERELO coordinates the complete intercity parcel journey. Authorized Personnel collects the parcel from the sender’s doorstep in one city, consolidates it at an origin operating hub, manages middle-mile corridor transit, and delivers directly to the recipient’s door.
              </p>
              <p className="text-sm text-text-secondary leading-relaxed">
                Every transition is logged into an operational ledger, ensuring verified custody from doorstep collection to doorstep handover.
              </p>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 3. Current Focus: Kano ↔ Katsina Corridor ─────────────── */}
      <Section variant="white" labelledBy="focus-heading">
        <Container size="content">
          <div className="grid md:grid-cols-2 gap-8 items-center max-w-4xl mx-auto">
            <div className="space-y-4">
              <Badge variant="corridor">Current Operations</Badge>
              <h2 id="focus-heading" className="text-2xl sm:text-3xl font-bold text-cerelo-navy">
                Focused Execution on the {CORRIDOR_DATA.name}
              </h2>
              <p className="text-sm text-text-secondary leading-relaxed">
                We currently operate exclusively on the Kano ↔ Katsina corridor in both directions. By building operational excellence and clear standard procedures on this route first, we ensure every delivery meets our standards.
              </p>
              <div className="pt-1">
                <CorridorBadge size="md" />
              </div>
            </div>

            <div className="p-6 sm:p-8 rounded-2xl bg-cerelo-navy text-white space-y-4 shadow-card">
              <div className="flex items-center gap-2 text-cerelo-orange-light font-bold text-sm">
                <MapPin className="w-4 h-4" aria-hidden="true" />
                <span>Operating Hub Scope</span>
              </div>
              <ul className="space-y-3 text-xs text-white/80">
                <li className="flex items-center justify-between pb-2 border-b border-white/15">
                  <span>{CORRIDOR_DATA.origin.hubName}</span>
                  <strong className="text-white">{CORRIDOR_DATA.origin.state}</strong>
                </li>
                <li className="flex items-center justify-between">
                  <span>{CORRIDOR_DATA.destination.hubName}</span>
                  <strong className="text-white">{CORRIDOR_DATA.destination.state}</strong>
                </li>
              </ul>
              <p className="text-[11px] text-white/55 leading-relaxed pt-2">
                {CORRIDOR_DATA.operationalBoundaryNotice}
              </p>
            </div>
          </div>
        </Container>
      </Section>

      {/* ── 4. Operating Principles ────────────────────────────────── */}
      <Section variant="subtle" labelledBy="principles-heading">
        <Container size="content">
          <SectionHeader
            eyebrow="Operating Principles"
            title="The Core Values Guiding CERELO Operations"
            titleId="principles-heading"
            description="Our network operates on discipline, verified facts, and strict custody accountability."
            align="center"
            className="mb-12 max-w-2xl mx-auto"
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 max-w-4xl mx-auto">
            {OPERATING_PRINCIPLES.map(({ title, description, icon: Icon }) => (
              <Card key={title} hoverable className="space-y-3 bg-surface-white p-6">
                <div className="w-10 h-10 rounded-lg bg-cerelo-navy text-white flex items-center justify-center">
                  <Icon className="w-5 h-5" aria-hidden="true" />
                </div>
                <h3 className="text-base font-bold text-cerelo-navy">{title}</h3>
                <p className="text-xs text-text-secondary leading-relaxed">
                  {description}
                </p>
              </Card>
            ))}
          </div>
        </Container>
      </Section>

      {/* ── 5. Future Vision / Disciplined Growth ─────────────────── */}
      <Section variant="white">
        <Container size="content">
          <div className="bg-cerelo-navy text-white p-8 sm:p-12 rounded-2xl space-y-6 max-w-4xl mx-auto shadow-card">
            <Badge variant="orange">Disciplined Growth</Badge>
            <h2 className="text-2xl sm:text-3xl font-black">
              Starting with Kano &amp; Katsina. Building for Scale.
            </h2>
            <p className="text-sm text-text-inverse/75 leading-relaxed max-w-2xl">
              We are starting with the Kano ↔ Katsina corridor to establish our operating foundation, standard procedures, and customer trust. Over time, this foundation will power connected trade corridors across Northern Nigeria.
            </p>
            <div className="pt-2 flex flex-wrap items-center gap-3">
              <Button href={SITE_CONFIG.ctaDestinations.sendPackage.href} variant="white" size="lg">
                <span>{SITE_CONFIG.ctaDestinations.sendPackage.label}</span>
                <ArrowRight className="w-4 h-4" aria-hidden="true" />
              </Button>
              <Button href="/how-it-works" variant="outline" size="lg" className="text-white border-white/40 hover:bg-white/10 hover:text-white">
                Learn How It Works
              </Button>
            </div>
          </div>
        </Container>
      </Section>
    </div>
  );
}
