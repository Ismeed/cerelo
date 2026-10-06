import type { Metadata } from 'next';
import { ArrowRight } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { CorridorBadge } from '@/components/ui/CorridorBadge';
import { ProcessSteps } from '@/components/ui/ProcessSteps';
import { StatusTimeline } from '@/components/ui/StatusTimeline';
import { Input, Textarea, Select } from '@/components/ui/Input';
import { AccordionItem } from '@/components/ui/Accordion';

export const metadata: Metadata = {
  title: 'Design System & Component Library — CERELO Internal',
  description: 'Internal reference for CERELO design tokens, typography, and reusable UI components.',
  robots: {
    index: false,
    follow: false,
  },
};

export default function DesignSystemPage() {
  const sampleSteps = [
    { number: 1, label: 'Request', description: 'Sender enters details in app.' },
    { number: 2, label: 'Pickup', description: 'Personnel collects package.' },
    { number: 3, label: 'Transit', description: 'Corridor movement.' },
    { number: 4, label: 'Delivery', description: 'Doorstep release.' },
  ];

  return (
    <div className="py-12 space-y-16">
      <Container size="content">
        <div className="space-y-3 pb-8 border-b border-border">
          <Badge variant="orange">Internal Living Styleguide</Badge>
          <h1 className="text-3xl sm:text-4xl font-black text-cerelo-navy">
            CERELO Design System &amp; UI Primitives
          </h1>
          <p className="text-sm text-text-secondary max-w-2xl">
            This page provides visual reference for all design tokens, typography scales, buttons,
            cards, badges, and form components established in Prompt 3.
          </p>
        </div>

        {/* ── 1. Color Tokens ────────────────────────────────────────── */}
        <section className="space-y-6 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">1. Brand &amp; Semantic Colors</h2>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <div className="p-4 rounded-xl bg-cerelo-navy text-white space-y-1">
              <span className="text-xs font-bold block">cerelo-navy</span>
              <span className="text-[11px] font-mono opacity-80">#1A2B4A</span>
            </div>
            <div className="p-4 rounded-xl bg-cerelo-navy-deep text-white space-y-1">
              <span className="text-xs font-bold block">cerelo-navy-deep</span>
              <span className="text-[11px] font-mono opacity-80">#0E1B30</span>
            </div>
            <div className="p-4 rounded-xl bg-cerelo-orange text-white space-y-1">
              <span className="text-xs font-bold block">cerelo-orange</span>
              <span className="text-[11px] font-mono opacity-80">#F4630A</span>
            </div>
            <div className="p-4 rounded-xl bg-cerelo-orange-soft text-cerelo-orange border border-cerelo-orange/20 space-y-1">
              <span className="text-xs font-bold block">cerelo-orange-soft</span>
              <span className="text-[11px] font-mono">#FDEEE4</span>
            </div>
          </div>
        </section>

        {/* ── 2. Corridor Badge ──────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">2. Corridor Visuals</h2>
          <div className="flex flex-wrap items-center gap-6 p-6 bg-surface-white rounded-xl border border-border">
            <div>
              <span className="text-xs text-text-muted block mb-2">Small</span>
              <CorridorBadge size="sm" />
            </div>
            <div>
              <span className="text-xs text-text-muted block mb-2">Medium (Default)</span>
              <CorridorBadge size="md" />
            </div>
            <div>
              <span className="text-xs text-text-muted block mb-2">Large</span>
              <CorridorBadge size="lg" />
            </div>
            <div className="bg-cerelo-navy p-4 rounded-lg">
              <span className="text-xs text-white/70 block mb-2">Inverted (Dark Mode)</span>
              <CorridorBadge inverted size="md" />
            </div>
          </div>
        </section>

        {/* ── 3. Buttons ────────────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">3. Buttons</h2>
          <div className="space-y-4 p-6 bg-surface-white rounded-xl border border-border">
            <div className="flex flex-wrap items-center gap-3">
              <Button variant="primary" size="md">
                <span>Primary Action</span>
                <ArrowRight className="w-4 h-4" />
              </Button>
              <Button variant="secondary" size="md">
                Secondary Action
              </Button>
              <Button variant="outline" size="md">
                Outline Action
              </Button>
              <Button variant="ghost" size="md">
                Ghost Action
              </Button>
              <Button variant="primary" size="md" loading>
                Loading State
              </Button>
            </div>
            <div className="bg-cerelo-navy p-4 rounded-lg flex items-center gap-3">
              <Button variant="white" size="md">
                White on Navy
              </Button>
              <Button variant="outline" size="md" className="text-white border-white/40 hover:bg-white/10 hover:text-white">
                Outline on Navy
              </Button>
            </div>
          </div>
        </section>

        {/* ── 4. Badges ─────────────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">4. Badges &amp; Tags</h2>
          <div className="flex flex-wrap items-center gap-3 p-6 bg-surface-white rounded-xl border border-border">
            <Badge variant="orange">Orange Highlight</Badge>
            <Badge variant="corridor">Corridor Verified</Badge>
            <Badge variant="neutral">Neutral Metadata</Badge>
            <Badge variant="success">Operational Success</Badge>
          </div>
        </section>

        {/* ── 5. Process Steps ──────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">5. Process Steps</h2>
          <div className="p-6 bg-surface-white rounded-xl border border-border">
            <ProcessSteps steps={sampleSteps} orientation="horizontal" />
          </div>
        </section>

        {/* ── 6. Status Timeline ────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">6. 7-Stage Custody Timeline</h2>
          <div className="p-6 sm:p-8 bg-surface-white rounded-xl border border-border">
            <StatusTimeline currentStageKey="IN_TRANSIT" />
          </div>
        </section>

        {/* ── 7. Form Primitives ────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">7. Form Inputs &amp; Controls</h2>
          <div className="p-6 bg-surface-white rounded-xl border border-border space-y-4 max-w-lg">
            <Input label="Text Input" placeholder="Enter standard text" helper="This is a helper note." />
            <Input label="Required Field" placeholder="Required input" required error="This field is required." />
            <Select label="Select Dropdown">
              <option>Kano Origin Hub</option>
              <option>Katsina Destination Hub</option>
            </Select>
            <Textarea label="Textarea Note" placeholder="Enter detailed note..." />
          </div>
        </section>

        {/* ── 8. Accordion ──────────────────────────────────────────── */}
        <section className="space-y-4 pt-8">
          <h2 className="text-xl font-bold text-cerelo-navy">8. Accordion Item</h2>
          <div className="space-y-3 max-w-2xl">
            <AccordionItem
              id="ds-sample-1"
              question="What is the Kano ↔ Katsina corridor coverage?"
              answer="CERELO provides doorstep pickup and delivery across metropolitan Kano and Katsina with verified personnel."
              defaultOpen
            />
            <AccordionItem
              id="ds-sample-2"
              question="How are delivery payments collected?"
              answer="Delivery fees are collected physically by CERELO Personnel at doorstep pickup or delivery."
            />
          </div>
        </section>
      </Container>
    </div>
  );
}
