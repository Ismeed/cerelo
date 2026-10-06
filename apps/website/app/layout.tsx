import { Suspense } from 'react';
import type { Metadata, Viewport } from 'next';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { SITE_CONFIG } from '@/lib/constants';
import './globals.css';

export const viewport: Viewport = {
  themeColor: '#1A2B4A',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

const isProduction = process.env.NEXT_PUBLIC_ENV === 'production';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_CONFIG.url),
  title: {
    template: `%s | ${SITE_CONFIG.name}`,
    default: `${SITE_CONFIG.name} — Door-to-Door Intercity Delivery (Kano ↔ Katsina)`,
  },
  description: SITE_CONFIG.description,
  keywords: [
    'door to door delivery Kano Katsina',
    'Kano to Katsina delivery',
    'Katsina to Kano parcel delivery',
    'parcel delivery Kano',
    'parcel delivery Katsina',
    'intercity delivery Kano Katsina',
    'business delivery Kano Katsina',
    'CERELO Logistics',
  ],
  authors: [{ name: 'CERELO Logistics' }],
  creator: 'CERELO Logistics',
  publisher: 'CERELO Logistics',
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/icon.png', sizes: '32x32', type: 'image/png' },
    ],
    apple: [{ url: '/apple-icon.png', sizes: '182x182', type: 'image/png' }],
  },
  openGraph: {
    type: 'website',
    locale: 'en_NG',
    url: SITE_CONFIG.url,
    siteName: SITE_CONFIG.name,
    title: `${SITE_CONFIG.name} — Door-to-Door Intercity Delivery (Kano ↔ Katsina)`,
    description: SITE_CONFIG.description,
    images: [
      {
        url: SITE_CONFIG.ogImage,
        width: 1200,
        height: 630,
        alt: 'CERELO Logistics — Kano ↔ Katsina Intercity Delivery',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: `${SITE_CONFIG.name} — Door-to-Door Intercity Delivery (Kano ↔ Katsina)`,
    description: SITE_CONFIG.description,
    images: [SITE_CONFIG.ogImage],
  },
  robots: isProduction
    ? {
        index: true,
        follow: true,
        googleBot: {
          index: true,
          follow: true,
          'max-video-preview': -1,
          'max-image-preview': 'large',
          'max-snippet': -1,
        },
      }
    : {
        index: false,
        follow: false,
        googleBot: {
          index: false,
          follow: false,
        },
      },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="flex flex-col min-h-screen">
        {/* Accessible Skip Link — First focusable element in DOM */}
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-50 focus:px-4 focus:py-2 focus:bg-cerelo-orange focus:text-white focus:font-bold focus:rounded-md focus:shadow-lg focus:outline-none focus:ring-2 focus:ring-white"
        >
          Skip to main content
        </a>
        <Suspense fallback={<div className="h-20 bg-white border-b border-border" />}>
          <Header />
        </Suspense>
        <main id="main-content" className="flex-grow">
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}

