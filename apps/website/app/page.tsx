import type { Metadata } from 'next';
import { HomeHero } from '@/components/home/HomeHero';
import { HomeProblem } from '@/components/home/HomeProblem';
import { HomeProcess } from '@/components/home/HomeProcess';
import { HomeTracking } from '@/components/home/HomeTracking';
import { HomeAudience } from '@/components/home/HomeAudience';
import { HomeCorridor } from '@/components/home/HomeCorridor';
import { HomeTrust } from '@/components/home/HomeTrust';
import { HomeFAQPreview } from '@/components/home/HomeFAQPreview';
import { HomeCTA } from '@/components/home/HomeCTA';
import { SITE_CONFIG } from '@/lib/config/site';

// ─── SEO Metadata ─────────────────────────────────────────────────────────────

export const metadata: Metadata = {
  title: 'CERELO | Door-to-Door Parcel Delivery — Kano & Katsina',
  description:
    'CERELO is a technology-enabled intercity logistics platform providing organized, trackable door-to-door parcel delivery on the Kano ↔ Katsina corridor in Nigeria.',
  alternates: {
    canonical: SITE_CONFIG.url,
  },
  openGraph: {
    title: 'CERELO | Door-to-Door Parcel Delivery — Kano & Katsina',
    description:
      'Organized, trackable door-to-door parcel delivery on the Kano ↔ Katsina corridor. From sender doorstep to receiver doorstep.',
    url: SITE_CONFIG.url,
    siteName: SITE_CONFIG.name,
    images: [
      {
        url: SITE_CONFIG.ogImage,
        width: 1200,
        height: 630,
        alt: 'CERELO — Intercity Door-to-Door Parcel Delivery',
      },
    ],
    locale: 'en_NG',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'CERELO | Door-to-Door Parcel Delivery — Kano & Katsina',
    description:
      'Organized, trackable door-to-door parcel delivery on the Kano ↔ Katsina corridor.',
    images: [SITE_CONFIG.ogImage],
  },
};

// ─── Organization Structured Data ─────────────────────────────────────────────
// Name, URL, and logo only — no unconfirmed operational details.

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: SITE_CONFIG.name,
  url: SITE_CONFIG.url,
  logo: `${SITE_CONFIG.url}/images/cerelo-badge-dark.jpg`,
};

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function HomePage() {
  return (
    <>
      {/* Organization structured data */}
      <script
        type="application/ld+json"
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }}
      />

      {/* 1. Hero — immediate product comprehension */}
      <HomeHero />

      {/* 2. Problem / Better Way — why CERELO exists */}
      <HomeProblem />

      {/* 3. How It Works — 4-step process preview */}
      <HomeProcess />

      {/* 4. Shipment Visibility — tracking story */}
      <HomeTracking />

      {/* 5. Individuals & Businesses — who it serves */}
      <HomeAudience />

      {/* 6. Corridor — Kano ↔ Katsina focus */}
      <HomeCorridor />

      {/* 7. Trust & Custody — operational accountability */}
      <HomeTrust />

      {/* 8. FAQ Preview — preemptive objection handling */}
      <HomeFAQPreview />

      {/* 9. Final CTA — conversion close */}
      <HomeCTA />
    </>
  );
}
