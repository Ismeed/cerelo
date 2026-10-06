export interface ContactConfig {
  email: string | null;
  phone: string | null;
  hours: string | null;
  operatingDays: string | null;
}

export interface SiteConfig {
  name: string;
  /** Pending legal confirmation — do not render publicly without approval */
  legalNamePending: string;
  tagline: string;
  description: string;
  url: string;
  domain: string;
  ogImage: string;
  corridor: {
    name: string;
    route: string;
    cities: [string, string];
    direction: string;
  };
  /**
   * Contact fields confirmed by product team in session.
   * Set any field to null to hide it from all public-facing surfaces.
   * Components must gracefully hide null values — never render placeholders.
   */
  contact: ContactConfig;
  ctaDestinations: {
    sendPackage: {
      href: string;
      label: string;
      description: string;
    };
    trackShipment: {
      href: string;
      label: string;
    };
    businessInquiry: {
      href: string;
      label: string;
    };
  };
  brandPhrases: {
    /** Primary tagline — safe to use sitewide */
    primary: string;
    /** Use only where corridor context makes coverage expectation clear */
    aspirational: string;
    subtext: string;
  };
}

export const SITE_CONFIG: SiteConfig = {
  name: 'CERELO',
  /** Pending legal/registration confirmation */
  legalNamePending: 'CERELO Logistics Network Ltd',
  tagline: 'Deliver with trust.',
  description:
    'CERELO is a technology-enabled intercity logistics platform providing organized, trackable door-to-door parcel delivery on the Kano ↔ Katsina corridor in Nigeria.',
  url: 'https://cerelonet.com',
  domain: 'cerelonet.com',
  ogImage: '/images/cerelo-badge-dark.jpg',
  corridor: {
    name: 'Kano ↔ Katsina Corridor',
    route: 'Kano ↔ Katsina',
    cities: ['Kano', 'Katsina'],
    direction: 'Bidirectional — Kano to Katsina and Katsina to Kano',
  },
  contact: {
    // Unverified public contact details set to null — all UI surfaces gracefully omit null fields
    email: null,
    phone: null,
    hours: null,
    operatingDays: null,
  },
  ctaDestinations: {
    sendPackage: {
      href: '/how-it-works#get-started',
      label: 'Send a Package',
      description: 'Book doorstep pickup via the CERELO Customer App',
    },
    trackShipment: {
      href: '/track',
      label: 'Track Shipment',
    },
    businessInquiry: {
      href: '/contact',
      label: 'Contact Operations',
    },
  },
  brandPhrases: {
    primary: 'Deliver with trust.',
    aspirational: 'Door to Door. Anywhere You Need.',
    subtext: 'From sender doorstep to receiver doorstep across Kano and Katsina.',
  },
};
