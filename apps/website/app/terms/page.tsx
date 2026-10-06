import type { Metadata } from 'next';
import Link from 'next/link';
import { AlertTriangle, ShieldCheck, MapPin, DollarSign, XCircle } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Breadcrumbs } from '@/components/ui/Breadcrumbs';
import { SITE_CONFIG } from '@/lib/config/site';
import { LEGAL_CONFIG } from '@/lib/config/legal';

export const metadata: Metadata = {
  title: 'Terms of Service | CERELO',
  description:
    'CERELO Terms of Service (Draft): Intercity door-to-door parcel delivery terms, sender responsibilities, payment modes, and cancellation rules on the Kano ↔ Katsina corridor.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/terms`,
  },
};

const TOC_SECTIONS = [
  { id: 'about-terms', label: '1. About These Terms' },
  { id: 'service-scope', label: '2. Operating Corridor & Service Scope' },
  { id: 'eligibility', label: '3. Legal Capacity & Account Security' },
  { id: 'shipment-request', label: '4. Creating a Shipment Request' },
  { id: 'inspection-custody', label: '5. Inspection & Custody Handover' },
  { id: 'sender-obligations', label: '6. Sender Obligations & Packaging' },
  { id: 'prohibited-items', label: '7. Prohibited & Restricted Items' },
  { id: 'pricing-verification', label: '8. Pricing & Size Verification' },
  { id: 'payment-modes', label: '9. Payment Modes & Physical Collections' },
  { id: 'cancellation-rules', label: '10. Cancellation & Cutoff Rules' },
  { id: 'middle-mile', label: '11. Intercity Transport Coordination' },
  { id: 'milestone-tracking', label: '12. Milestone Tracking & Delivery Code' },
  { id: 'delivery-completion', label: '13. Doorstep Delivery Completion' },
  { id: 'failed-delivery', label: '14. Failed Delivery & Undelivered Items' },
  { id: 'delays', label: '15. Delays & Transit Factors' },
  { id: 'loss-damage', label: '16. Loss, Damage & Claims' },
  { id: 'consumer-rights', label: '17. Statutory Consumer Rights' },
  { id: 'suspension', label: '18. Service Suspension & Misuse' },
  { id: 'intellectual-property', label: '19. Intellectual Property' },
  { id: 'disputes-law', label: '20. Governing Law & Dispute Resolution' },
  { id: 'terms-updates', label: '21. Updates to Terms & Contact' },
];

export default function TermsPage() {
  return (
    <div className="py-10 sm:py-16 space-y-12">
      <Container size="content">
        <Breadcrumbs items={[{ label: 'Terms of Service' }]} />

        {/* ── Page Header ────────────────────────────────────────── */}
        <div className="space-y-4 max-w-3xl">
          <div className="flex items-center gap-2">
            <Badge variant="neutral">Service Agreement</Badge>
            <span className="text-xs font-mono text-text-muted">v{LEGAL_CONFIG.termsVersion}</span>
          </div>
          <h1 className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight">
            Terms of Service
          </h1>
          <p className="text-sm sm:text-base text-text-secondary leading-relaxed">
            Status: <strong className="text-cerelo-navy">{LEGAL_CONFIG.termsEffectiveDate}</strong>
          </p>
        </div>

        {/* ── Draft Notice Banner ─────────────────────────────────── */}
        {LEGAL_CONFIG.isDraftPendingApproval && (
          <div className="p-5 bg-status-warning-bg border border-status-warning/30 rounded-2xl flex items-start gap-3.5 shadow-subtle">
            <AlertTriangle className="w-5 h-5 text-status-warning shrink-0 mt-0.5" aria-hidden="true" />
            <div className="space-y-1">
              <h2 className="text-sm font-bold text-text-primary">
                Operational Working Draft — Pending Management &amp; Legal Review
              </h2>
              <p className="text-xs text-text-secondary leading-relaxed">
                These terms reflect the operational and technical foundation of CERELO V1. They are an operational working draft currently undergoing formal Nigerian legal and regulatory review prior to commercial launch.
              </p>
            </div>
          </div>
        )}

        {/* ── Key Operational Commitments Summary Card ────────────── */}
        <div className="p-6 sm:p-8 bg-surface-white rounded-2xl border border-border space-y-6 shadow-subtle">
          <div className="flex items-center gap-2 border-b border-border pb-4 font-bold text-base text-cerelo-navy">
            <ShieldCheck className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
            <span>Key Service Terms at a Glance</span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-xs text-text-secondary">
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <MapPin className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Kano ↔ Katsina Corridor Only</span>
              </div>
              <p className="leading-relaxed">
                Service operates exclusively between Kano and Katsina in both directions. Same-city intracity dispatch is not supported.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <DollarSign className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Physical Fee Collections</span>
              </div>
              <p className="leading-relaxed">
                Delivery fees are collected physically by CERELO Personnel under three confirmed payment options: Sender Pays, Receiver Pays, or Split Payment.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <XCircle className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>3-Phase Cancellation Rules</span>
              </div>
              <p className="leading-relaxed">
                Self-cancellation before pickup confirmation; coordinated request after confirmation but before transit; self-cancellation unavailable once in transit.
              </p>
            </div>
          </div>
        </div>

        {/* ── Main Layout: Table of Contents + Terms Content ──────── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
          {/* Table of Contents Sidebar */}
          <aside className="lg:col-span-4 sticky top-24 space-y-4 p-6 bg-surface-subtle rounded-2xl border border-border text-xs">
            <h2 className="font-bold text-sm text-cerelo-navy">Table of Contents</h2>
            <nav className="space-y-1.5 max-h-[70vh] overflow-y-auto pr-2" aria-label="Terms of Service Sections">
              {TOC_SECTIONS.map((sec) => (
                <a
                  key={sec.id}
                  href={`#${sec.id}`}
                  className="block py-1 text-text-secondary hover:text-cerelo-orange transition-colors duration-150"
                >
                  {sec.label}
                </a>
              ))}
            </nav>
          </aside>

          {/* Terms Text Column */}
          <article className="lg:col-span-8 bg-surface-white p-6 sm:p-12 rounded-2xl border border-border space-y-12 text-sm text-text-secondary leading-relaxed shadow-subtle">
            {/* 1. About These Terms */}
            <section id="about-terms" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                1. About These Terms
              </h2>
              <p>
                These Terms of Service (&quot;Terms&quot;) constitute a draft service agreement between you (&quot;Customer&quot;, &quot;Sender&quot;, or &quot;User&quot;) and CERELO (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;), governing your use of the CERELO Customer Mobile Application, our website (<Link href="/" className="text-cerelo-navy font-semibold hover:underline">cerelonet.com</Link>), and our intercity parcel delivery coordination network.
              </p>
              <p>
                By requesting a parcel pickup, accepting a delivery handover, or accessing CERELO digital platforms, you acknowledge these operational terms. These terms are subject to formal legal review before final binding adoption.
              </p>
            </section>

            {/* 2. Service Scope */}
            <section id="service-scope" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                2. Operating Corridor &amp; Service Scope
              </h2>
              <p>
                CERELO V1 is a specialized <strong>intercity door-to-door parcel delivery platform</strong> operating exclusively on the <strong>Kano ↔ Katsina corridor</strong> in Northern Nigeria (both Kano to Katsina and Katsina to Kano directions).
              </p>
              <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-2 text-xs">
                <strong className="block text-cerelo-navy font-semibold text-sm">Operational Boundaries</strong>
                <ul className="list-disc pl-5 space-y-1 text-text-secondary">
                  <li><strong>No Intracity Dispatch:</strong> CERELO does not provide local intra-city errand or dispatch services within the same city.</li>
                  <li><strong>Corridor Exclusivity:</strong> Delivery requests to locations outside designated operating zones in Kano State and Katsina State will be rejected at booking or pickup.</li>
                </ul>
              </div>
            </section>

            {/* 3. Eligibility */}
            <section id="eligibility" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                3. Legal Capacity &amp; Account Security
              </h2>
              <p>
                To book a delivery, you must possess the legal capacity to enter into binding logistics agreements under applicable Nigerian law. Specific age eligibility and contracting policies remain subject to formal legal review.
              </p>
              <p>
                Authentication on CERELO platforms utilizes passwordless Email One-Time Passwords (OTPs) and Google OAuth. You are responsible for safeguarding access to your email and mobile device and agree to notify CERELO of any unauthorized access to your account.
              </p>
            </section>

            {/* 4. Shipment Request */}
            <section id="shipment-request" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                4. Creating a Shipment Request
              </h2>
              <p>
                When creating a delivery request, the Sender must provide accurate and complete information, including:
              </p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li>Exact sender doorstep pickup address, landmarks, and reachable contact telephone.</li>
                <li>Exact recipient doorstep delivery address, landmarks, recipient name, and reachable telephone number.</li>
                <li>Estimated parcel size tier (Small, Medium, Large) and parcel category description.</li>
                <li>Selection of payment responsibility (Sender Pays, Receiver Pays, or Split Payment).</li>
              </ul>
              <p className="text-xs text-text-muted">
                A submitted shipment request creates an operational pickup assignment but does not establish CERELO custody until physical parcel inspection and confirmation by Personnel.
              </p>
            </section>

            {/* 5. Inspection & Custody */}
            <section id="inspection-custody" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                5. Physical Parcel Inspection &amp; Custody Handover
              </h2>
              <p>
                <strong>The Custody Boundary:</strong> CERELO accepts formal custody of a parcel only when authorized CERELO Personnel completes physical inspection at the sender&apos;s doorstep and executes the <strong>Confirm Parcel</strong> transaction in the mobile app.
              </p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li>Personnel will physically inspect the parcel to verify package integrity and suitability for intercity transit.</li>
                <li>Personnel will verify the declared size tier against physical characteristics.</li>
                <li>The assigned Delivery Code (<span className="font-mono">CRL-XXXX-XXXX</span>) is confirmed, establishing custody into the CERELO network.</li>
              </ul>
            </section>

            {/* 6. Sender Obligations */}
            <section id="sender-obligations" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                6. Sender Obligations &amp; Packaging Standards
              </h2>
              <p>The Sender is responsible for:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li>Ensuring all items are packaged with sufficient protective material to withstand ordinary motor transport vibrations and handling across intercity roads.</li>
                <li>Ensuring that fragile items are clearly identified and packaged with appropriate internal cushioning.</li>
                <li>Ensuring that parcel contents comply with all applicable Nigerian laws, postal regulations, and safety rules.</li>
              </ul>
            </section>

            {/* 7. Prohibited Items */}
            <section id="prohibited-items" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                7. Prohibited &amp; Restricted Items Framework
              </h2>
              <p>
                Customers must not send items prohibited by Nigerian law or applicable courier regulations:
              </p>
              <div className="space-y-3 text-xs">
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Items Prohibited by Law &amp; Regulations</strong>
                  <ul className="list-disc pl-5 space-y-1 text-text-secondary">
                    <li>Illegal narcotics, controlled drugs, and unapproved chemical substances.</li>
                    <li>Firearms, ammunition, fireworks, explosives, and military hardware.</li>
                    <li>Flammable, corrosive, toxic, or hazardous materials.</li>
                    <li>Stolen property or counterfeit merchandise.</li>
                  </ul>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Additional Operational Restrictions</strong>
                  <ul className="list-disc pl-5 space-y-1 text-text-secondary">
                    <li>Physical currency (cash notes or coins) shipped inside parcel packages. (Note: Delivery service fees collected physically by staff at the doorstep are permitted).</li>
                  </ul>
                </div>
              </div>
              <p className="text-xs text-text-muted italic">
                A formal, comprehensive prohibited items policy is currently pending management and legal approval.
              </p>
            </section>

            {/* 8. Pricing & Verification */}
            <section id="pricing-verification" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                8. Pricing, Quotes &amp; Physical Size Verification
              </h2>
              <p>
                Delivery fees are determined by the corridor route and confirmed parcel size tier (Small, Medium, Large):
              </p>
              <p className="text-xs text-text-secondary">
                <strong>Price Adjustment:</strong> If physical inspection at pickup reveals that a parcel exceeds the sender&apos;s declared size tier, Personnel will adjust the size tier in the app. The revised fee must be acknowledged before custody confirmation.
              </p>
            </section>

            {/* 9. Payment Modes */}
            <section id="payment-modes" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                9. Payment Modes &amp; Physical Collections
              </h2>
              <p>CERELO supports three distinct payment options in V1 operations:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Sender Pays:</strong> Full delivery fee is collected physically by CERELO Personnel at the sender&apos;s doorstep during parcel pickup.</li>
                <li><strong>Receiver Pays:</strong> Full delivery fee is collected physically by CERELO Personnel at the recipient&apos;s doorstep before parcel handover.</li>
                <li><strong>Split Payment:</strong> The fee is divided between Sender and Receiver in predetermined portions confirmed at booking.</li>
              </ul>
              <p className="text-xs text-text-muted">
                Delivery fees are collected physically by CERELO Personnel and recorded in the operational system.
              </p>
            </section>

            {/* 10. Cancellation */}
            <section id="cancellation-rules" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                10. Cancellation &amp; Operational Cutoff Rules
              </h2>
              <p>
                Customer cancellation is governed by our operational state machine:
              </p>
              <div className="space-y-3 text-xs">
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Phase 1: Before Parcel Confirmation (Cancel Request)</strong>
                  <p>While the shipment is in <em>Requested</em> status before CERELO Personnel completes physical inspection and accepts custody, the Sender may execute <strong>Cancel Request</strong> in the mobile app.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Phase 2: After Confirmation but Before Transit (Cancel Delivery)</strong>
                  <p>After CERELO Personnel has accepted custody but before the parcel departs in transit on the corridor, the Sender may request <strong>Cancel Delivery</strong>. Applicable return, refund, or handling arrangements will follow operational guidelines.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Phase 3: Once In Transit or Later (Cutoff Closed)</strong>
                  <p>Once the shipment enters <em>In Transit</em> status on the intercity corridor, customer self-cancellation is unavailable and the delivery will proceed to the destination hub.</p>
                </div>
              </div>
            </section>

            {/* 11. Middle-Mile */}
            <section id="middle-mile" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                11. Intercity Transport Coordination
              </h2>
              <p>
                CERELO may use third-party transport providers for part of the intercity journey while coordinating the shipment through its service and maintaining chain-of-custody tracking.
              </p>
              <p>
                CERELO remains responsible for coordinating your delivery, recording milestone progress, and executing destination reconciliation at the receiving hub.
              </p>
            </section>

            {/* 12. Milestone Tracking */}
            <section id="milestone-tracking" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                12. Milestone Tracking &amp; Delivery Code Nature
              </h2>
              <p>
                Shipment visibility is status-based and driven by verified physical custody milestones recorded by Personnel. CERELO does not provide live GPS moving-vehicle map tracking.
              </p>
              <p>
                The Delivery Code (<span className="font-mono">CRL-XXXX-XXXX</span>) is a public tracking identifier and is not an authentication credential. Public tracking views display only city-level routing and milestone timestamps to safeguard customer privacy.
              </p>
            </section>

            {/* 13. Delivery Completion */}
            <section id="delivery-completion" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                13. Doorstep Delivery Completion
              </h2>
              <p>
                Delivery is completed when CERELO Personnel arrives at the recipient&apos;s address, collects outstanding delivery fees (if Receiver Pays or Split Payment), and hands over the parcel to the recipient.
              </p>
              <p>
                Personnel records the <strong>Mark Delivered</strong> transaction in the mobile app, which constitutes primary operational proof of delivery.
              </p>
            </section>

            {/* 14. Failed Delivery */}
            <section id="failed-delivery" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                14. Failed Delivery &amp; Undelivered Items
              </h2>
              <p>
                If a recipient is unavailable, unreachable, or delivery cannot be completed at the doorstep, Personnel will record an exception event, and operations dispatch will coordinate appropriate re-attempt or return instructions.
              </p>
              <p className="text-xs text-text-muted italic">
                A formal failed-delivery, re-attempt, and return fee policy is currently pending management approval.
              </p>
            </section>

            {/* 15. Delays */}
            <section id="delays" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                15. Delays &amp; Transit Factors
              </h2>
              <p>
                While CERELO maintains structured operational schedules between Kano and Katsina, transit timelines may occasionally be influenced by severe weather, road conditions, traffic incidents, or security checkpoints. CERELO communicates milestone updates via the tracking portal.
              </p>
            </section>

            {/* 16. Loss & Damage */}
            <section id="loss-damage" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                16. Loss, Damage &amp; Claims Framework
              </h2>
              <p>
                CERELO maintains an immutable chain-of-custody ledger for every parcel. In the event of suspected loss or physical damage to a package while in CERELO custody:
              </p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li>Customers should report suspected loss or damage as soon as reasonably possible through CERELO&apos;s approved support channel.</li>
                <li>CERELO will investigate operational event logs and incident records.</li>
                <li>Remedies and claims will be evaluated in accordance with applicable Nigerian logistics standards.</li>
              </ul>
              <p className="text-xs text-text-muted italic">
                A formal liability schedule, compensation formula, and cargo claims policy is currently pending management and legal approval.
              </p>
            </section>

            {/* 17. Consumer Rights */}
            <section id="consumer-rights" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                17. Statutory Consumer Rights
              </h2>
              <p>
                Nothing in these Terms excludes, restricts, or modifies any non-excludable statutory rights, warranties, or remedies available to consumers under the Federal Competition and Consumer Protection Act 2018 (FCCPA) or other applicable Nigerian consumer protection laws.
              </p>
            </section>

            {/* 18. Suspension */}
            <section id="suspension" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                18. Service Suspension &amp; Misuse
              </h2>
              <p>
                CERELO reserves the right to suspend accounts, refuse pickup, or terminate access where reasonably necessary to prevent fraud, protect staff safety, enforce prohibited-item rules, or comply with legal obligations.
              </p>
            </section>

            {/* 19. Intellectual Property */}
            <section id="intellectual-property" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                19. Intellectual Property
              </h2>
              <p>
                All trademarks, logos, service marks, website designs, mobile software, and brand assets associated with CERELO are the proprietary property of CERELO and its operators. Customers are granted a limited, revocable license to access the platforms solely to arrange and track deliveries.
              </p>
            </section>

            {/* 20. Disputes & Law */}
            <section id="disputes-law" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                20. Governing Law &amp; Dispute Resolution
              </h2>
              <p>
                These Terms are governed by and construed in accordance with the laws of the <strong>Federal Republic of Nigeria</strong>.
              </p>
              <p>
                In the event of any controversy, claim, or dispute, the parties agree to first seek amicable resolution through CERELO&apos;s internal operations escalation desk before initiating formal legal proceedings in competent courts within Nigeria.
              </p>
            </section>

            {/* 21. Updates & Contact */}
            <section id="terms-updates" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                21. Updates to Terms &amp; Contact
              </h2>
              <p>
                We may revise these Terms periodically. Continued use of CERELO services following the posting of updated Terms constitutes acceptance.
              </p>
              <p>
                For questions regarding these draft Terms, please contact our operations team via our <Link href="/contact" className="text-cerelo-navy font-semibold hover:underline">Contact Page</Link>.
              </p>
            </section>
          </article>
        </div>
      </Container>
    </div>
  );
}
