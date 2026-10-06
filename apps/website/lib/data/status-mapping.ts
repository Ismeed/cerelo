export interface StatusDisplayInfo {
  customerLabel: string;
  stageKey: string;
  stageIndex: number; // 0 to 6 for standard 7 stages, -1 for cancelled
  badgeVariant: 'neutral' | 'orange' | 'corridor' | 'success' | 'warning' | 'error';
  description: string;
  isTerminal: boolean;
  isCancelled: boolean;
  isFailed: boolean;
}

export const BACKEND_STATUS_MAP: Record<string, StatusDisplayInfo> = {
  REQUESTED: {
    customerLabel: 'Shipment Requested',
    stageKey: 'REQUESTED',
    stageIndex: 0,
    badgeVariant: 'neutral',
    description: 'Pickup request created. Awaiting personnel collection.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  PICKUP_IN_PROGRESS: {
    customerLabel: 'Personnel Dispatched for Pickup',
    stageKey: 'REQUESTED',
    stageIndex: 0,
    badgeVariant: 'orange',
    description: 'Authorized CERELO Personnel is on the way to sender pickup address.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  PARCEL_CONFIRMED: {
    customerLabel: 'Parcel Confirmed in Custody',
    stageKey: 'PARCEL_CONFIRMED',
    stageIndex: 1,
    badgeVariant: 'corridor',
    description: 'Package inspected, accepted into CERELO custody, and Delivery Code verified.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  AT_ORIGIN_HUB: {
    customerLabel: 'Consolidated at Origin Hub',
    stageKey: 'AT_ORIGIN_HUB',
    stageIndex: 2,
    badgeVariant: 'corridor',
    description: 'Received at origin operating hub and staged for corridor batching.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  BATCHED: {
    customerLabel: 'Batched for Departure',
    stageKey: 'AT_ORIGIN_HUB',
    stageIndex: 2,
    badgeVariant: 'corridor',
    description: 'Consolidated into sealed corridor batch ready for transit.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  IN_TRANSIT: {
    customerLabel: 'In Transit on Corridor',
    stageKey: 'IN_TRANSIT',
    stageIndex: 3,
    badgeVariant: 'orange',
    description: 'Moving between Kano and Katsina under verified batch manifest.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  ARRIVED_DESTINATION: {
    customerLabel: 'Arrived at Destination City',
    stageKey: 'ARRIVED_DESTINATION',
    stageIndex: 4,
    badgeVariant: 'corridor',
    description: 'Reconciled at destination operating hub and sorted for final-mile delivery.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  OUT_FOR_DELIVERY: {
    customerLabel: 'Out for Doorstep Delivery',
    stageKey: 'OUT_FOR_DELIVERY',
    stageIndex: 5,
    badgeVariant: 'orange',
    description: 'With delivery personnel on final-mile doorstep approach.',
    isTerminal: false,
    isCancelled: false,
    isFailed: false,
  },
  DELIVERED: {
    customerLabel: 'Delivered',
    stageKey: 'DELIVERED',
    stageIndex: 6,
    badgeVariant: 'success',
    description: 'Successfully delivered to recipient at doorstep.',
    isTerminal: true,
    isCancelled: false,
    isFailed: false,
  },
  DELIVERY_FAILED: {
    customerLabel: 'Delivery Attempt Update',
    stageKey: 'OUT_FOR_DELIVERY',
    stageIndex: 5,
    badgeVariant: 'warning',
    description: 'Delivery attempted. Re-attempt coordination in progress.',
    isTerminal: false,
    isCancelled: false,
    isFailed: true,
  },
  CANCELLED: {
    customerLabel: 'Cancelled',
    stageKey: 'CANCELLED',
    stageIndex: -1,
    badgeVariant: 'error',
    description: 'This shipment request was cancelled.',
    isTerminal: true,
    isCancelled: true,
    isFailed: false,
  },
};

export function getStatusDisplay(status: string): StatusDisplayInfo {
  return (
    BACKEND_STATUS_MAP[status.toUpperCase()] || {
      customerLabel: status,
      stageKey: 'REQUESTED',
      stageIndex: 0,
      badgeVariant: 'neutral',
      description: 'Shipment is active in the CERELO network.',
      isTerminal: false,
      isCancelled: false,
      isFailed: false,
    }
  );
}

/** Format milestone event date/time for Nigerian locale */
export function formatMilestoneTime(isoString: string): string {
  try {
    const date = new Date(isoString);
    if (isNaN(date.getTime())) return '';
    return new Intl.DateTimeFormat('en-NG', {
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    }).format(date);
  } catch {
    return '';
  }
}
