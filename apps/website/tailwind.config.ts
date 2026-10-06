import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // ─── Brand Navy ────────────────────────────────────────────────
        // Primary trust/authority color. Use for structure, headings, dark sections.
        cerelo: {
          navy: '#1A2B4A',        // Primary brand navy
          'navy-deep': '#0E1B30', // Deepest navy — dark section backgrounds
          'navy-soft': '#2C4270', // Softer navy — hover states, secondary elements

          // ─── Brand Orange ─────────────────────────────────────────────
          // Strategic accent. Use for primary CTAs, progress, and key highlights.
          // WCAG 2 AA compliant (4.65:1 contrast against white)
          orange: '#C84800',       // Accessible action orange
          'orange-hover': '#A83B00', // Hover darken — 15% darker
          'orange-soft': '#FDEEE4', // Pale orange — subtle highlights, active chips
          'orange-light': '#FF8534', // Lighter orange — used on dark backgrounds only
        },

        // ─── Surfaces ─────────────────────────────────────────────────
        // 60–70% of visual weight. Provide breathing room between elements.
        surface: {
          DEFAULT: '#FAFAFA',    // Page background
          white: '#FFFFFF',      // Component/card surface
          subtle: '#F2F4F7',     // Alternate section background, input fills
          dark: '#0E1B30',       // Dark section background (= cerelo-navy-deep)
        },

        // ─── Borders ──────────────────────────────────────────────────
        border: {
          DEFAULT: '#E4E7EC',    // Standard card/input border
          strong: '#D0D5DD',     // Emphasis borders
          dark: '#1E3A5F',       // Borders on dark/navy sections
        },

        // ─── Typography ───────────────────────────────────────────────
        text: {
          primary: '#101828',    // High-contrast body copy (14:1)
          secondary: '#344054',  // Supporting descriptive text (7.2:1)
          muted: '#5A667A',      // Accessible captions & metadata (5.2:1 against #FFFFFF, 4.9:1 against #FAFAFA)
          inverse: '#FFFFFF',    // Text on dark backgrounds
        },

        // ─── Semantic Status ─────────────────────────────────────────
        status: {
          success: '#0E8A4F',
          'success-bg': '#ECFDF3',
          warning: '#B54708',
          'warning-bg': '#FFFAEB',
          error: '#D92D20',
          'error-bg': '#FEF3F2',
          info: '#026AA2',
          'info-bg': '#F0F9FF',
        },
      },

      // ─── Typography ─────────────────────────────────────────────────
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
      },
      fontSize: {
        // Fluid type scale using clamp — prevents 8-line wrapping on mobile
        'display': ['clamp(2rem, 5vw, 3.5rem)', { lineHeight: '1.1', letterSpacing: '-0.03em', fontWeight: '900' }],
        'hero': ['clamp(1.75rem, 4vw, 3rem)', { lineHeight: '1.1', letterSpacing: '-0.025em', fontWeight: '800' }],
        'h1': ['clamp(1.5rem, 3vw, 2.25rem)', { lineHeight: '1.2', letterSpacing: '-0.02em', fontWeight: '700' }],
        'h2': ['clamp(1.25rem, 2.5vw, 1.75rem)', { lineHeight: '1.25', letterSpacing: '-0.015em', fontWeight: '700' }],
        'h3': ['clamp(1.05rem, 2vw, 1.25rem)', { lineHeight: '1.35', letterSpacing: '-0.01em', fontWeight: '600' }],
        'body-lg': ['1.0625rem', { lineHeight: '1.7' }],
        'body': ['0.9375rem', { lineHeight: '1.65' }],
        'body-sm': ['0.8125rem', { lineHeight: '1.6' }],
        'caption': ['0.75rem', { lineHeight: '1.5' }],
        'overline': ['0.6875rem', { lineHeight: '1.4', letterSpacing: '0.1em' }],
      },

      // ─── Containers ─────────────────────────────────────────────────
      maxWidth: {
        site: '1280px',    // Full page max-width
        content: '960px',  // Default content container
        narrow: '720px',   // Legal/document pages, focused reading
        reading: '65ch',   // Optimal prose measure — never exceed for paragraphs
      },

      // ─── Spacing ────────────────────────────────────────────────────
      spacing: {
        'section-sm': '3rem',    // 48px — compact mobile sections
        'section-md': '5rem',    // 80px — standard section padding
        'section-lg': '7rem',    // 112px — hero/feature section
        'card': '1.5rem',        // 24px — card internal padding
        'card-lg': '2.5rem',     // 40px — large card internal padding
      },

      // ─── Border Radius ───────────────────────────────────────────────
      // Restrained rounding — modern but not bubbly fintech
      borderRadius: {
        'xs': '4px',    // Tags, chips, status indicators
        'sm': '8px',    // Inputs, small buttons
        'DEFAULT': '10px', // Default
        'md': '12px',   // Standard buttons, cards
        'lg': '16px',   // Feature cards, panels
        'xl': '20px',   // Large containers, media wells
        '2xl': '24px',  // Section-level containers, hero panels
        'full': '9999px', // Pills only
      },

      // ─── Shadows ─────────────────────────────────────────────────────
      // Minimal — prefer surface contrast and borders over heavy shadows
      boxShadow: {
        'subtle':      '0 1px 2px rgba(16, 24, 40, 0.05)',
        'card':        '0 1px 3px rgba(16, 24, 40, 0.08), 0 1px 2px rgba(16, 24, 40, 0.04)',
        'card-hover':  '0 8px 20px -4px rgba(16, 24, 40, 0.10), 0 3px 8px -2px rgba(16, 24, 40, 0.04)',
        'header':      '0 1px 3px rgba(16, 24, 40, 0.06)',
        'dropdown':    '0 8px 24px -4px rgba(16, 24, 40, 0.15)',
        'orange-glow': '0 6px 16px -3px rgba(244, 99, 10, 0.30)',
        'none':        'none',
      },

      // ─── Responsive Breakpoints ──────────────────────────────────────
      screens: {
        'xs': '375px',
        'sm': '640px',
        'md': '768px',
        'lg': '1024px',
        'xl': '1280px',
        '2xl': '1440px',
      },

      // ─── Transitions & Motion ────────────────────────────────────────
      transitionDuration: {
        '100': '100ms',
        '150': '150ms',
        '200': '200ms',
        '300': '300ms',
        '400': '400ms',
      },
      transitionTimingFunction: {
        'smooth': 'cubic-bezier(0.4, 0, 0.2, 1)',
        'enter': 'cubic-bezier(0, 0, 0.2, 1)',
        'exit': 'cubic-bezier(0.4, 0, 1, 1)',
      },
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0', transform: 'translateY(4px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'accordion-down': {
          '0%': { height: '0', opacity: '0' },
          '100%': { height: 'var(--accordion-content-height)', opacity: '1' },
        },
        'accordion-up': {
          '0%': { height: 'var(--accordion-content-height)', opacity: '1' },
          '100%': { height: '0', opacity: '0' },
        },
        'pulse-dot': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.4' },
        },
      },
      animation: {
        'fade-in': 'fade-in 200ms ease-out',
        'accordion-down': 'accordion-down 200ms ease-out',
        'accordion-up': 'accordion-up 200ms ease-out',
        'pulse-dot': 'pulse-dot 1.5s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

export default config;
