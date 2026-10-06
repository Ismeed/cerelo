import type { Metadata } from 'next';
import Link from 'next/link';
import { AlertTriangle, ShieldCheck, Lock, EyeOff, FileText } from 'lucide-react';
import { Container } from '@/components/ui/Container';
import { Badge } from '@/components/ui/Badge';
import { Breadcrumbs } from '@/components/ui/Breadcrumbs';
import { SITE_CONFIG } from '@/lib/config/site';
import { LEGAL_CONFIG } from '@/lib/config/legal';

export const metadata: Metadata = {
  title: 'Privacy Policy | CERELO',
  description:
    'CERELO Privacy Policy (Draft): Learn how personal data is handled in our door-to-door parcel delivery operations on the Kano ↔ Katsina corridor.',
  alternates: {
    canonical: `${SITE_CONFIG.url}/privacy`,
  },
};

const TOC_SECTIONS = [
  { id: 'introduction', label: '1. Introduction & Overview' },
  { id: 'who-we-are', label: '2. Who Operates CERELO' },
  { id: 'scope', label: '3. Scope of this Policy' },
  { id: 'information-collected', label: '4. Information We Collect' },
  { id: 'how-collected', label: '5. How We Collect Information' },
  { id: 'purposes', label: '6. Purposes of Processing' },
  { id: 'lawful-bases', label: '7. Lawful Bases for Processing' },
  { id: 'receiver-data', label: '8. Receiver Information' },
  { id: 'public-tracking', label: '9. Public Shipment Tracking' },
  { id: 'data-sharing', label: '10. How We Share Information' },
  { id: 'service-providers', label: '11. Cloud Service Providers' },
  { id: 'cross-border', label: '12. International Processing' },
  { id: 'data-retention', label: '13. Data Retention Principles' },
  { id: 'security', label: '14. Security Safeguards' },
  { id: 'privacy-rights', label: '15. Your Data Protection Rights' },
  { id: 'exercising-rights', label: '16. Exercising Your Rights' },
  { id: 'contracting-capacity', label: '17. Legal Capacity & Age' },
  { id: 'cookies', label: '18. Cookies & Website Technologies' },
  { id: 'automated-decisions', label: '19. Operational Decision-Making' },
  { id: 'policy-changes', label: '20. Policy Updates' },
  { id: 'contact-complaints', label: '21. Contact & Complaints' },
];

export default function PrivacyPage() {
  return (
    <div className="py-10 sm:py-16 space-y-12">
      <Container size="content">
        <Breadcrumbs items={[{ label: 'Privacy Policy' }]} />

        {/* ── Page Header ────────────────────────────────────────── */}
        <div className="space-y-4 max-w-3xl">
          <div className="flex items-center gap-2">
            <Badge variant="neutral">Legal &amp; Privacy</Badge>
            <span className="text-xs font-mono text-text-muted">v{LEGAL_CONFIG.privacyVersion}</span>
          </div>
          <h1 className="text-3xl sm:text-5xl font-black text-cerelo-navy tracking-tight">
            Privacy Policy
          </h1>
          <p className="text-sm sm:text-base text-text-secondary leading-relaxed">
            Status: <strong className="text-cerelo-navy">{LEGAL_CONFIG.privacyEffectiveDate}</strong>
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
                This document describes the actual data-processing architecture and operational practices of CERELO V1. It is a working operational draft subject to formal Nigerian regulatory and legal counsel review prior to publication.
              </p>
            </div>
          </div>
        )}

        {/* ── Privacy at a Glance Summary Card ───────────────────── */}
        <div className="p-6 sm:p-8 bg-surface-white rounded-2xl border border-border space-y-6 shadow-subtle">
          <div className="flex items-center gap-2 border-b border-border pb-4 font-bold text-base text-cerelo-navy">
            <ShieldCheck className="w-5 h-5 text-cerelo-orange" aria-hidden="true" />
            <span>Privacy Principles at a Glance</span>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-xs text-text-secondary">
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <Lock className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Operational Use Only</span>
              </div>
              <p className="leading-relaxed">
                We collect personal information solely to coordinate doorstep pickups, corridor transit, and doorstep deliveries on the Kano ↔ Katsina corridor.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <EyeOff className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Protected Public Tracking</span>
              </div>
              <p className="leading-relaxed">
                Public Delivery Code and shared tracking lookups reveal zero customer names, zero phone numbers, zero street addresses, and zero parcel descriptions.
              </p>
            </div>
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 font-bold text-cerelo-navy">
                <FileText className="w-4 h-4 text-cerelo-orange" aria-hidden="true" />
                <span>Auditable Custody Records</span>
              </div>
              <p className="leading-relaxed">
                Physical custody handoffs are recorded in an immutable ledger to maintain parcel traceability and resolve delivery disputes.
              </p>
            </div>
          </div>
        </div>

        {/* ── Main Layout: Table of Contents + Policy Content ─────── */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
          {/* Table of Contents Sidebar */}
          <aside className="lg:col-span-4 sticky top-24 space-y-4 p-6 bg-surface-subtle rounded-2xl border border-border text-xs">
            <h2 className="font-bold text-sm text-cerelo-navy">Table of Contents</h2>
            <nav className="space-y-1.5 max-h-[70vh] overflow-y-auto pr-2" aria-label="Privacy Policy Sections">
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

          {/* Policy Text Column */}
          <article className="lg:col-span-8 bg-surface-white p-6 sm:p-12 rounded-2xl border border-border space-y-12 text-sm text-text-secondary leading-relaxed shadow-subtle">
            {/* 1. Introduction */}
            <section id="introduction" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                1. Introduction &amp; Overview
              </h2>
              <p>
                CERELO (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;) is an intercity parcel delivery platform coordinating door-to-door logistics services on the Kano ↔ Katsina corridor in Nigeria.
              </p>
              <p>
                This Privacy Policy explains how personal information is collected, used, shared, and protected when customers, recipients, merchants, and website visitors use the CERELO Customer Mobile Application, our website (<Link href="/" className="text-cerelo-navy font-semibold hover:underline">cerelonet.com</Link>), or our physical delivery coordination service.
              </p>
            </section>

            {/* 2. Who Operates CERELO */}
            <section id="who-we-are" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                2. Who Operates CERELO
              </h2>
              <p>
                The CERELO service is operated under the trading name <strong>{LEGAL_CONFIG.tradingName}</strong>. Formal corporate entity registration details, registered offices, and official company identifiers are subject to formal legal verification and will be published upon regulatory confirmation.
              </p>
              <p>
                CERELO acts as the data controller regarding customer accounts, delivery bookings, and operational shipment records under applicable Nigerian data protection laws.
              </p>
            </section>

            {/* 3. Scope */}
            <section id="scope" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                3. Scope of this Policy
              </h2>
              <p>This Privacy Policy applies to:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Registered Senders:</strong> Customers who create an account to book parcel deliveries.</li>
                <li><strong>Parcel Receivers:</strong> Individuals designated by senders to receive parcels at their doorstep.</li>
                <li><strong>Business Clients:</strong> Merchants and commercial traders utilizing CERELO pickup coordination.</li>
                <li><strong>Public Website Visitors:</strong> Individuals visiting <Link href="/" className="text-cerelo-navy font-medium hover:underline">cerelonet.com</Link> or utilizing the public tracking portal.</li>
              </ul>
            </section>

            {/* 4. Information We Collect */}
            <section id="information-collected" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                4. Information We Collect
              </h2>
              <p>We process only the minimum information necessary to execute logistics operations:</p>
              <div className="space-y-3 text-xs">
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Account &amp; Identity Data</strong>
                  <p>Full name, mobile telephone number, email address, account type (Individual or Business), and registered business name.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Sender &amp; Pickup Data</strong>
                  <p>Pickup address, specific landmarks, pickup contact name, and phone number.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Receiver &amp; Delivery Data</strong>
                  <p>Recipient name, destination delivery address, landmarks, delivery instructions, and recipient telephone number.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Shipment &amp; Physical Custody Data</strong>
                  <p>Parcel size tier (Small, Medium, Large), category description, declared characteristics, Delivery Code (<span className="font-mono">CRL-XXXX-XXXX</span>), QR identifiers, custody transfer timestamps, and personnel assignment records.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Commercial &amp; Payment Data</strong>
                  <p>Quoted delivery fee, confirmed physical fee, payment mode (Sender Pays, Receiver Pays, Split Payment), collection method, collection timestamp, and physical receipt records.</p>
                </div>
                <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1">
                  <strong className="block text-cerelo-navy font-semibold text-sm">Technical &amp; Authentication Metadata</strong>
                  <p>Firebase Cloud Messaging (FCM) push tokens, device operating system type (Android/iOS/Web), and authenticated session timestamps.</p>
                </div>
              </div>
            </section>

            {/* 5. How We Collect */}
            <section id="how-collected" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                5. How We Collect Information
              </h2>
              <p>Information is collected through three direct channels:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Direct User Input:</strong> When you register an account, authenticate via passwordless Email OTP or Google OAuth, or input shipment details.</li>
                <li><strong>Sender Provision:</strong> When a sender inputs the recipient&apos;s name, telephone number, and delivery address to arrange a parcel delivery.</li>
                <li><strong>Operational Generation:</strong> When CERELO Personnel inspects packages, confirms size tiers, scans QR codes at hubs, and records physical custody handoffs in our operational event ledger.</li>
              </ul>
            </section>

            {/* 6. Purposes of Processing */}
            <section id="purposes" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                6. Purposes of Processing
              </h2>
              <p>We process personal data strictly for operational, security, and administrative purposes:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li>To dispatch authorized CERELO Personnel to collect parcels at the sender&apos;s doorstep.</li>
                <li>To consolidate parcels at origin operating hubs and coordinate middle-mile transit on the Kano ↔ Katsina corridor.</li>
                <li>To navigate final-mile routes and complete physical handover to the recipient.</li>
                <li>To verify payment obligations and record physical collections accurately.</li>
                <li>To enable status-based milestone tracking via Delivery Codes and shared links.</li>
                <li>To resolve operational incidents, investigate lost/damaged parcel reports, and maintain an auditable chain of custody.</li>
                <li>To maintain operational and financial records necessary for commercial administration and statutory compliance.</li>
              </ul>
            </section>

            {/* 7. Lawful Bases */}
            <section id="lawful-bases" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                7. Lawful Bases for Processing
              </h2>
              <p>Processing activities are conducted under recognized lawful bases under Nigerian data protection law, subject to ongoing legal review:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Performance of a Contract:</strong> Processing sender details, pickup addresses, and payment obligations is necessary to execute the requested logistics service.</li>
                <li><strong>Legitimate Interests:</strong> Processing recipient contact details provided by senders to navigate delivery, send arrival alerts, and protect the platform against fraud.</li>
                <li><strong>Legal &amp; Regulatory Obligations:</strong> Retaining financial records and chain-of-custody logs to meet statutory accounting and commercial obligations.</li>
                <li><strong>User Request &amp; Authentication:</strong> Utilizing email OTP or federated authentication to securely identify users upon their request.</li>
              </ul>
            </section>

            {/* 8. Receiver Information */}
            <section id="receiver-data" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                8. Receiver Information &amp; Third-Party Provision
              </h2>
              <p>
                When senders book a shipment, they provide personal details for the designated recipient (name, phone number, delivery address). We process this information strictly to coordinate and complete doorstep delivery.
              </p>
              <p>
                Senders must have an appropriate basis for providing recipient information for delivery purposes. Receivers who do not hold a CERELO account may contact our team to understand what data is held regarding an incoming shipment.
              </p>
            </section>

            {/* 9. Public Shipment Tracking */}
            <section id="public-tracking" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                9. Public Shipment Tracking &amp; Privacy Protection
              </h2>
              <p>
                CERELO operates an authentic, status-based milestone tracking experience. To protect customer privacy:
              </p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Zero Customer Names:</strong> Public tracking lookups by Delivery Code or share token never reveal sender or receiver names.</li>
                <li><strong>Zero Phone Numbers:</strong> Contact telephone numbers are completely omitted from public tracking results.</li>
                <li><strong>Zero Street Addresses:</strong> Public results show only origin and destination cities (e.g. Kano → Katsina). Full street addresses are accessible only to assigned delivery staff.</li>
                <li><strong>Zero Content Details:</strong> Specific parcel contents and descriptions are excluded from public tracking.</li>
                <li><strong>Zero Real-Time Live GPS:</strong> We provide authentic custody status milestones rather than continuous live moving-map telemetry.</li>
              </ul>
            </section>

            {/* 10. How We Share Information */}
            <section id="data-sharing" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                10. How We Share Information
              </h2>
              <p>We do not sell, rent, or trade customer personal information. Information is shared strictly with:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Assigned CERELO Personnel:</strong> Field personnel assigned to your pickup or delivery receive only the specific names, addresses, and phone numbers required to navigate and complete the task.</li>
                <li><strong>Operational Staff &amp; Dispatch:</strong> Internal support staff assisting with parcel tracking, incident resolution, or customer inquiries.</li>
                <li><strong>Law Enforcement &amp; Regulatory Authorities:</strong> When required by a valid legal process, court order, or mandatory statutory requirement under Nigerian law.</li>
              </ul>
            </section>

            {/* 11. Service Providers */}
            <section id="service-providers" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                11. Cloud Service Providers &amp; Infrastructure
              </h2>
              <p>We engage trusted technical infrastructure providers to host and secure our systems:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Supabase, Inc.:</strong> Cloud database, authentication, and storage infrastructure.</li>
                <li><strong>Resend, Inc.:</strong> Transactional email delivery for passwordless authentication codes (OTPs).</li>
                <li><strong>Google LLC:</strong> Federated Google OAuth sign-in and Firebase Cloud Messaging (FCM) push notifications.</li>
                <li><strong>Vercel, Inc.:</strong> Web application hosting and content delivery.</li>
              </ul>
            </section>

            {/* 12. International Processing */}
            <section id="cross-border" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                12. International &amp; Cross-Border Processing
              </h2>
              <p>
                Our cloud service providers maintain infrastructure located outside Nigeria (including in Europe and North America). Where personal data is processed internationally, we work with service providers to establish appropriate data protection safeguards in accordance with Nigerian data protection requirements. Specific cross-border transfer documentation is undergoing formal legal review.
              </p>
            </section>

            {/* 13. Data Retention */}
            <section id="data-retention" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                13. Data Retention Principles
              </h2>
              <p>
                We retain personal information only for as long as reasonably necessary for the purposes for which it was collected, including operating the service, resolving disputes, maintaining appropriate operational records, and meeting applicable legal and commercial obligations.
              </p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Active Account Profiles:</strong> Retained while your account remains active.</li>
                <li><strong>Operational Custody Ledger:</strong> Custody transfer events and Delivery Codes are permanently recorded in an immutable ledger to maintain parcel traceability and verify delivery completion.</li>
                <li><strong>Financial &amp; Payment Records:</strong> Physical collection logs and transaction obligations are retained in accordance with applicable statutory accounting and tax standards.</li>
                <li><strong>Incident &amp; Claim Files:</strong> Retained for periods necessary to investigate claims, resolve disputes, and respond to legal inquiries.</li>
              </ul>
              <p className="text-xs text-text-muted italic">
                A formal corporate data retention schedule is currently pending legal and management approval.
              </p>
            </section>

            {/* 14. Security Safeguards */}
            <section id="security" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                14. Security Safeguards
              </h2>
              <p>CERELO implements organizational and technical safeguards appropriate to physical logistics operations:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Row Level Security (RLS):</strong> Database tables enforce default-deny access policies.</li>
                <li><strong>Role-Based Access Control (RBAC):</strong> Field personnel and operations administrators access only shipments within their assigned scope.</li>
                <li><strong>Server-Authoritative State Transitions:</strong> Custody and status mutations execute inside validated, atomic server transactions.</li>
                <li><strong>Encrypted Communications:</strong> All web and API traffic is encrypted in transit using Transport Layer Security (TLS/HTTPS).</li>
              </ul>
            </section>

            {/* 15. Your Privacy Rights */}
            <section id="privacy-rights" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                15. Your Data Protection Rights Under Nigerian Law
              </h2>
              <p>Under applicable Nigerian data protection law, you may have rights including:</p>
              <ul className="list-disc pl-5 space-y-1.5 text-xs text-text-secondary">
                <li><strong>Information &amp; Access:</strong> Requesting confirmation of whether we process your data and obtaining access.</li>
                <li><strong>Rectification:</strong> Requesting correction of inaccurate or incomplete personal information.</li>
                <li><strong>Objection:</strong> Objecting to processing based on legitimate interests where applicable.</li>
                <li><strong>Restriction:</strong> Requesting temporary restriction of processing in specific disputed circumstances.</li>
                <li><strong>Erasure / Deletion:</strong> Requesting deletion of your account profile, subject to statutory record-keeping and immutable ledger retention requirements.</li>
              </ul>
            </section>

            {/* 16. Exercising Your Rights */}
            <section id="exercising-rights" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                16. Exercising Your Rights
              </h2>
              <p>
                To exercise any data-protection right, please contact our team via our <Link href="/contact" className="text-cerelo-navy font-semibold hover:underline">Contact Page</Link>. Formal privacy request workflows will be activated upon commercial launch.
              </p>
              <p>
                Identity verification may be required before fulfilling data requests to protect account security.
              </p>
            </section>

            {/* 17. Legal Capacity */}
            <section id="contracting-capacity" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                17. Legal Capacity &amp; Age Eligibility
              </h2>
              <p>
                CERELO services are intended for individuals who possess the legal capacity to enter into binding logistics agreements under applicable Nigerian law. Specific age eligibility and contracting policies remain subject to formal legal review.
              </p>
            </section>

            {/* 18. Cookies */}
            <section id="cookies" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                18. Cookies &amp; Website Technologies
              </h2>
              <p>
                The public CERELO website uses strictly necessary technical storage required for basic operation, security, and navigation. We do not use third-party advertising or cross-site tracking cookies.
              </p>
            </section>

            {/* 19. Operational Decision-Making */}
            <section id="automated-decisions" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                19. Operational Decision-Making
              </h2>
              <p>
                CERELO does not subject users to decisions based solely on automated algorithmic profiling that produce legal or significant effects. Custody confirmation, parcel size tier verification, and delivery completion are verified through physical actions by authorized CERELO Personnel.
              </p>
            </section>

            {/* 20. Changes */}
            <section id="policy-changes" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                20. Changes to this Privacy Policy
              </h2>
              <p>
                We may update this Privacy Policy periodically to reflect operational refinements or regulatory developments. When updates occur, the status and version identifier at the top of this page will be revised. Material changes will be communicated via mobile app notices or website announcements.
              </p>
            </section>

            {/* 21. Contact & Complaints */}
            <section id="contact-complaints" className="space-y-3 scroll-mt-28">
              <h2 className="text-xl font-bold text-cerelo-navy border-b border-border pb-2">
                21. Contact Information &amp; Regulatory Inquiries
              </h2>
              <p>
                If you have questions regarding this draft Privacy Policy or our data handling practices, please connect with our operations team via our <Link href="/contact" className="text-cerelo-navy font-semibold hover:underline">Contact Page</Link>.
              </p>
              <p className="text-xs text-text-secondary">
                You may also refer to official information provided by the competent data protection authority in Nigeria:
              </p>
              <div className="p-4 rounded-xl bg-surface-subtle border border-border space-y-1 text-xs text-text-secondary">
                <strong className="block text-cerelo-navy font-bold">Nigeria Data Protection Commission (NDPC)</strong>
                <p>Website: <a href="https://ndpc.gov.ng" target="_blank" rel="noopener noreferrer" className="text-cerelo-orange hover:underline">ndpc.gov.ng</a></p>
                <p>Abuja, Federal Capital Territory, Nigeria</p>
              </div>
            </section>
          </article>
        </div>
      </Container>
    </div>
  );
}
