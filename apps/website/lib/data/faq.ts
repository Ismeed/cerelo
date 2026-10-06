export interface FAQItem {
  id: string;
  question: string;
  answer: string;
  category: string;
}

export interface FAQCategory {
  id: string;
  title: string;
  description: string;
  items: FAQItem[];
}

export const FAQ_CATEGORIES: FAQCategory[] = [
  {
    id: 'getting-started',
    title: 'Getting Started & Overview',
    description: 'What CERELO is and how the service works.',
    items: [
      {
        id: 'what-is-cerelo',
        question: 'What is CERELO?',
        answer:
          'CERELO is a technology-enabled intercity door-to-door logistics platform. We eliminate the stress of motor parks by collecting parcels directly from the sender\'s doorstep in one city and delivering them straight to the receiver\'s doorstep in the destination city — all on the Kano ↔ Katsina corridor.',
        category: 'getting-started',
      },
      {
        id: 'motor-park-difference',
        question: 'How is CERELO different from using motor parks or commercial drivers?',
        answer:
          'With CERELO, you do not travel to motor parks, negotiate rates individually, or hand over goods without any documentation. Our personnel collect from your door, every handoff is recorded in an operational ledger, and the receiver gets a doorstep delivery rather than having to search for a vehicle at a destination park.',
        category: 'getting-started',
      },
      {
        id: 'account-required',
        question: 'Do I need an account to send or track a parcel?',
        answer:
          'To book a pickup, you create an account on the CERELO customer mobile app. To track a shipment already in progress, you only need the unique Delivery Code (e.g. CRL-0000-0000) or the tracking link shared by the sender.',
        category: 'getting-started',
      },
    ],
  },
  {
    id: 'coverage',
    title: 'Corridor & Service Coverage',
    description: 'Supported cities and geographic boundaries.',
    items: [
      {
        id: 'supported-routes',
        question: 'Which cities does CERELO currently serve?',
        answer:
          'CERELO currently operates exclusively on the Kano ↔ Katsina corridor in Nigeria. Both directions are supported — Kano to Katsina, and Katsina to Kano. We do not currently operate local same-city intracity dispatch or routes outside this corridor.',
        category: 'coverage',
      },
      {
        id: 'pickup-areas',
        question: 'Does CERELO pick up from any address within Kano or Katsina?',
        answer:
          'We provide doorstep pickup and delivery across the metropolitan areas of both cities. Contact our support team to confirm availability at your specific address before booking.',
        category: 'coverage',
      },
    ],
  },
  {
    id: 'sending-pickup',
    title: 'Sending & Pickup Operations',
    description: 'How packages are collected, inspected, and processed.',
    items: [
      {
        id: 'pickup-process',
        question: 'How does doorstep pickup work?',
        answer:
          'After submitting a shipment request on the CERELO mobile app, a CERELO Personnel user is dispatched to your specified address. They physically inspect the package, confirm the size tier, and take official custody — generating your unique Delivery Code.',
        category: 'sending-pickup',
      },
      {
        id: 'parcel-sizes',
        question: 'What parcel sizes can I send?',
        answer:
          'Pricing is based on parcel size tiers confirmed at pickup. The personnel will verify the appropriate tier during the collection visit. Contact our support team for current size and weight details.',
        category: 'sending-pickup',
      },
    ],
  },
  {
    id: 'tracking',
    title: 'Tracking & Shipment Visibility',
    description: 'How tracking works and what data is visible.',
    items: [
      {
        id: 'how-tracking-works',
        question: 'How do I track the progress of my parcel?',
        answer:
          'Every CERELO shipment has a unique Delivery Code and a shareable tracking link. Tracking shows verified operational stages as the parcel moves: from pickup confirmation through origin processing, corridor transit, destination arrival, and doorstep delivery.',
        category: 'tracking',
      },
      {
        id: 'live-gps-clarification',
        question: 'Does CERELO provide live GPS tracking?',
        answer:
          'No. CERELO provides authentic status-based tracking recorded at physical custody handoffs — not simulated GPS maps. You see verified stage updates that reflect what has actually happened with your parcel.',
        category: 'tracking',
      },
      {
        id: 'receiver-privacy',
        question: 'Can anyone see my address or phone number using the tracking link?',
        answer:
          'No. For customer privacy, public tracking links display only masked names and city-level routing. Complete street addresses and phone numbers are never shown publicly.',
        category: 'tracking',
      },
    ],
  },
  {
    id: 'payments',
    title: 'Payments & Fees',
    description: 'Payment options and how fees are collected.',
    items: [
      {
        id: 'payment-modes',
        question: 'Who pays for the delivery?',
        answer:
          'You choose a payment mode when booking: Sender Pays (fee collected at pickup), Receiver Pays (fee collected when the receiver receives the parcel), or Split Payment (shared between both parties).',
        category: 'payments',
      },
      {
        id: 'payment-methods',
        question: 'How is the delivery fee collected?',
        answer:
          'In V1, delivery fees are collected physically by CERELO Personnel at the point of pickup or doorstep delivery, depending on your chosen payment mode.',
        category: 'payments',
      },
    ],
  },
  {
    id: 'cancellation',
    title: 'Cancellation & Lifecycle Rules',
    description: 'When and how you can cancel a shipment.',
    items: [
      {
        id: 'cancel-request-window',
        question: 'Can I cancel before personnel arrives for pickup?',
        answer:
          'Yes. While your shipment is in the "Requested" state — before CERELO Personnel confirms collection — you can tap "Cancel Request" in the app to cancel immediately.',
        category: 'cancellation',
      },
      {
        id: 'cancel-delivery-window',
        question: 'Can I cancel after the parcel has been collected?',
        answer:
          'You can request cancellation while the parcel is still at the origin hub before middle-mile corridor transit begins. Once the shipment transitions to "In Transit", self-service cancellation is no longer available.',
        category: 'cancellation',
      },
    ],
  },
  {
    id: 'business',
    title: 'For Businesses & Merchants',
    description: 'Using CERELO for regular commercial deliveries.',
    items: [
      {
        id: 'merchant-benefits',
        question: 'How does CERELO help merchants and online sellers?',
        answer:
          'Merchants can book regular parcel pickups from their shop or market stall without traveling to motor parks. CERELO handles doorstep delivery to buyers across the corridor, and shareable tracking links keep your customers informed without you needing to field status calls.',
        category: 'business',
      },
      {
        id: 'business-account-signup',
        question: 'How do I register a business account on CERELO?',
        answer:
          'Download the CERELO customer app and select the business account option during registration. You can then begin booking doorstep shipment pickups across the Kano ↔ Katsina corridor.',
        category: 'business',
      },
    ],
  },
];
