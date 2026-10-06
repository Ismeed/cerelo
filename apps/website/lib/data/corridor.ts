/**
 * Corridor operational data.
 *
 * IMPORTANT: Only include facts explicitly confirmed by product/operations leadership.
 * Do NOT add: distances, transit durations, daily departure schedules, neighborhood
 * pickup zone lists, hub street addresses, or delivery time guarantees.
 */

export interface CorridorCity {
  name: string;
  state: string;
  /** Generic hub name — no physical address until confirmed */
  hubName: string;
}

export interface CorridorInfo {
  id: string;
  name: string;
  canonicalRoute: string;
  isBidirectional: boolean;
  origin: CorridorCity;
  destination: CorridorCity;
  /** Core service facts — keep to verified operational commitments only */
  serviceCommitments: string[];
  operationalBoundaryNotice: string;
}

export const CORRIDOR_DATA: CorridorInfo = {
  id: 'KAN-KAT',
  name: 'Kano ↔ Katsina Corridor',
  canonicalRoute: 'Kano ↔ Katsina',
  isBidirectional: true,
  origin: {
    name: 'Kano',
    state: 'Kano State',
    hubName: 'Kano Service Area',
  },
  destination: {
    name: 'Katsina',
    state: 'Katsina State',
    hubName: 'Katsina Service Area',
  },
  serviceCommitments: [
    'Doorstep collection by CERELO Personnel at the sender address',
    'Physical parcel inspection and size verification at pickup',
    'Secure consolidation at origin operating hub',
    'Coordinated intercity middle-mile transport across the corridor',
    'Doorstep handover directly to the recipient address',
  ],
  operationalBoundaryNotice:
    'CERELO V1 operates exclusively on the Kano ↔ Katsina corridor. Same-city intracity dispatch and routes outside this corridor are not supported.',
};
