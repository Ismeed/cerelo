export interface NavItem {
  label: string;
  href: string;
  description?: string;
  isExternal?: boolean;
}

export const PRIMARY_NAV_ITEMS: readonly NavItem[] = [
  { label: 'How It Works', href: '/how-it-works', description: 'Understand our door-to-door delivery process' },
  { label: 'For Businesses', href: '/business', description: 'Solutions for merchants, traders, and online sellers' },
  { label: 'Track Shipment', href: '/track', description: 'Check status using your Delivery Code' },
  { label: 'About', href: '/about', description: 'Our operational network and mission' },
] as const;

export const MOBILE_NAV_ITEMS: readonly NavItem[] = [
  { label: 'Home', href: '/' },
  { label: 'How It Works', href: '/how-it-works' },
  { label: 'For Businesses', href: '/business' },
  { label: 'Track Shipment', href: '/track' },
  { label: 'About CERELO', href: '/about' },
  { label: 'Frequently Asked Questions', href: '/faq' },
  { label: 'Contact & Support', href: '/contact' },
] as const;

export const FOOTER_NAV = {
  service: [
    { label: 'How It Works', href: '/how-it-works' },
    { label: 'For Businesses & Merchants', href: '/business' },
    { label: 'Track a Shipment', href: '/track' },
    { label: 'Kano ↔ Katsina Corridor', href: '/how-it-works#corridor' },
  ],
  company: [
    { label: 'About CERELO', href: '/about' },
    { label: 'Frequently Asked Questions', href: '/faq' },
    { label: 'Contact Operations', href: '/contact' },
  ],
  legal: [
    { label: 'Privacy Policy', href: '/privacy' },
    { label: 'Terms of Service', href: '/terms' },
  ],
} as const;

export function isActiveRoute(currentPathname: string, targetHref: string): boolean {
  if (targetHref === '/') {
    return currentPathname === '/';
  }
  return currentPathname.startsWith(targetHref);
}
