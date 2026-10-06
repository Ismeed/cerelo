export interface LifecycleStage {
  key: string;
  stepNumber: number;
  label: string;
  shortDescription: string;
  detailedDescription: string;
  custodyHolder: string;
  trackingVisibilityText: string;
}

export const LIFECYCLE_STAGES: readonly LifecycleStage[] = [
  {
    key: 'REQUESTED',
    stepNumber: 1,
    label: 'Shipment Requested',
    shortDescription: 'Pickup request created. Awaiting personnel collection.',
    detailedDescription:
      'Sender creates the shipment request via the CERELO mobile app. Origin, destination, parcel attributes, and payment responsibility are recorded.',
    custodyHolder: 'Sender',
    trackingVisibilityText: 'Pickup request received. CERELO Personnel assigned.',
  },
  {
    key: 'PARCEL_CONFIRMED',
    stepNumber: 2,
    label: 'Parcel Confirmed & Collected',
    shortDescription: 'Personnel inspected and collected package into CERELO custody.',
    detailedDescription:
      'Authorized CERELO Personnel arrives at sender doorstep, verifies package integrity, confirms parcel size tier, and generates the unique Delivery Code.',
    custodyHolder: 'Personnel (Pickup)',
    trackingVisibilityText: 'Package inspected and accepted into CERELO custody.',
  },
  {
    key: 'AT_ORIGIN_HUB',
    stepNumber: 3,
    label: 'In CERELO Custody / Origin Hub',
    shortDescription: 'Consolidated and staged at origin operating point.',
    detailedDescription:
      'Parcel is received at the origin operating hub, logged into the immutable operational ledger, and batched for middle-mile corridor transit.',
    custodyHolder: 'Origin Operating Hub',
    trackingVisibilityText: 'Consolidated at origin hub. Staged for scheduled departure.',
  },
  {
    key: 'IN_TRANSIT',
    stepNumber: 4,
    label: 'In Transit on Corridor',
    shortDescription: 'Kano ↔ Katsina middle-mile transport underway.',
    detailedDescription:
      'The parcel moves across the corridor via coordinated commercial transport capacity on the Kano ↔ Katsina route.',
    custodyHolder: 'Corridor Transit Capacity',
    trackingVisibilityText: 'Moving on Kano ↔ Katsina corridor.',
  },
  {
    key: 'ARRIVED_DESTINATION',
    stepNumber: 5,
    label: 'Arrived at Destination City',
    shortDescription: 'Parcel arrived and reconciled at destination sorting hub.',
    detailedDescription:
      'Destination hub personnel unpacks the transit batch, reconciles every item against the manifest, and stages parcel for final-mile dispatch.',
    custodyHolder: 'Destination Operating Hub',
    trackingVisibilityText: 'Arrived at destination city hub. Sorted for final-mile route.',
  },
  {
    key: 'OUT_FOR_DELIVERY',
    stepNumber: 6,
    label: 'Out for Doorstep Delivery',
    shortDescription: 'Personnel en route to recipient address.',
    detailedDescription:
      'Destination personnel takes custody and navigates directly to the recipient’s doorstep in the target city.',
    custodyHolder: 'Personnel (Delivery)',
    trackingVisibilityText: 'With delivery personnel on final-mile doorstep approach.',
  },
  {
    key: 'DELIVERED',
    stepNumber: 7,
    label: 'Delivered',
    shortDescription: 'Package successfully handed over to recipient.',
    detailedDescription:
      'Personnel hands over parcel, collects payment if Receiver Pays, and records delivery completion in the immutable ledger.',
    custodyHolder: 'Receiver',
    trackingVisibilityText: 'Successfully delivered to recipient at doorstep.',
  },
] as const;

export const TRACKING_SECURITY_NOTICE = {
  title: 'Status-Based Tracking & Privacy Protection',
  summary:
    'CERELO provides authentic, stage-by-stage operational status updates. We do NOT provide live GPS moving-map tracking. For customer privacy, public tracking links display only status milestones and city-level routing—never full street addresses, customer names, or personal contact numbers.',
};
