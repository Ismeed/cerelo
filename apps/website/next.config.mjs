/** @type {import('next').NextConfig} */

const PRODUCTION_ORIGIN = 'https://cerelonet.com';

/**
 * Content Security Policy
 *
 * Public website sources:
 * - Supabase (Kano ↔ Katsina corridor tracking RPC) — derived from NEXT_PUBLIC_SUPABASE_URL
 * - Vercel infrastructure
 *
 * Intentionally conservative — no wildcard external domains.
 * CSP connect-src and img-src are built dynamically from the configured
 * Supabase project URL so the same config works for both staging
 * (plsoyomwoqysharmuddl) and production (mgffdifedhquwiirkhyy)
 * without hard-coding either project ref.
 *
 * Inline styles are required by Tailwind CSS (style= attribute usage).
 */

// Derive the allowed Supabase origin from the env var at build time.
// Falls back to production ref so the official build is always safe.
const supabaseUrl =
  process.env.NEXT_PUBLIC_SUPABASE_URL ||
  'https://mgffdifedhquwiirkhyy.supabase.co';

const CSP_DIRECTIVES = [
  "default-src 'self'",
  // Scripts: self + Next.js inline bootstrap (required for hydration)
  "script-src 'self' 'unsafe-inline'",
  // Styles: self + Tailwind inline styles
  "style-src 'self' 'unsafe-inline'",
  // Images: self + data URIs (for inline SVG icons) + configured Supabase storage
  `img-src 'self' data: blob: ${supabaseUrl}`,
  // Connect: self + configured Supabase REST (public tracking RPC — no realtime needed on website)
  `connect-src 'self' ${supabaseUrl}`,
  // Fonts: self (fonts loaded locally via Next.js font optimization)
  "font-src 'self' data:",
  // Media: self
  "media-src 'self'",
  // Forms: self only
  "form-action 'self'",
  // Framing: deny all external framing
  "frame-ancestors 'none'",
  // Object: none (no plugins)
  "object-src 'none'",
  // Base URI: self
  "base-uri 'self'",
  // Upgrade insecure requests only on production HTTPS
  ...(process.env.NEXT_PUBLIC_ENV === 'production' ? ["upgrade-insecure-requests"] : []),
].join('; ');

/**
 * Indexing gate — NEXT_PUBLIC_ENV === 'production' enables indexing.
 *
 * Vercel Production currently does NOT have NEXT_PUBLIC_ENV=production,
 * so noindex/nofollow remains active throughout pre-launch.
 * Prompt 10 will set NEXT_PUBLIC_ENV=production to enable indexing.
 */
const isProduction = process.env.NEXT_PUBLIC_ENV === 'production';

const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    formats: ['image/avif', 'image/webp'],
    // Allow only self-hosted images (no external image domains for website)
    remotePatterns: [],
  },

  async headers() {
    const securityHeaders = [
      // Prevent MIME type sniffing
      {
        key: 'X-Content-Type-Options',
        value: 'nosniff',
      },
      // Prevent clickjacking via older X-Frame-Options (belt-and-suspenders with CSP frame-ancestors)
      {
        key: 'X-Frame-Options',
        value: 'DENY',
      },
      // Control referrer information — do not leak tokens to third-party origins
      {
        key: 'Referrer-Policy',
        value: 'strict-origin-when-cross-origin',
      },
      // Restrict access to browser features not needed by the public website
      {
        key: 'Permissions-Policy',
        value: 'camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()',
      },
      // Content Security Policy
      {
        key: 'Content-Security-Policy',
        value: CSP_DIRECTIVES,
      },
      // HSTS — only effective once deployed on HTTPS production
      {
        key: 'Strict-Transport-Security',
        value: 'max-age=63072000; includeSubDomains',
      },
    ];

    // Pre-launch indexing protection: when NEXT_PUBLIC_ENV !== 'production', send X-Robots-Tag: noindex, nofollow
    if (!isProduction) {
      securityHeaders.push({
        key: 'X-Robots-Tag',
        value: 'noindex, nofollow',
      });
    }

    return [
      {
        // Apply security headers to all routes
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
};

export default nextConfig;
