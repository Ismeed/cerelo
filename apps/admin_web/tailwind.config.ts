import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Cerelo brand colors — matches cerelo_colors.dart
        cerelo: {
          navy: '#1A2B4A',
          'navy-light': '#2C4270',
          'navy-dark': '#0E1B30',
          orange: '#F4630A',
          'orange-light': '#FF8534',
          'orange-dark': '#BF4B00',
        },
        // Design tokens
        surface: '#FAFAFA',
        'surface-variant': '#F2F4F7',
        border: '#E4E7EC',
        'border-strong': '#D0D5DD',
        text: {
          primary: '#101828',
          secondary: '#475467',
          tertiary: '#98A2B3',
        },
        status: {
          success: '#12B76A',
          'success-bg': '#ECFDF3',
          warning: '#F79009',
          'warning-bg': '#FFFAEB',
          error: '#F04438',
          'error-bg': '#FEF3F2',
          info: '#0BA5EC',
          'info-bg': '#F0F9FF',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      fontSize: {
        'delivery-code': ['18px', { lineHeight: '1', letterSpacing: '2px', fontWeight: '700' }],
      },
      borderRadius: {
        sm: '8px',
        DEFAULT: '12px',
        lg: '16px',
        xl: '24px',
      },
      boxShadow: {
        card: '0 1px 3px rgba(16, 24, 40, 0.1), 0 1px 2px rgba(16, 24, 40, 0.06)',
        'card-hover': '0 4px 8px rgba(16, 24, 40, 0.12), 0 2px 4px rgba(16, 24, 40, 0.08)',
        sidebar: '1px 0 0 #E4E7EC',
      },
    },
  },
  plugins: [],
}

export default config
