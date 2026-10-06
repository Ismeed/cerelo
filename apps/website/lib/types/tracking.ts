export interface PublicMilestone {
  event_type: string;
  created_at: string;
}

export type TrackingLookupType = 'DELIVERY_CODE' | 'SHARE_TOKEN';

export interface PublicTrackingData {
  is_valid: true;
  lookup_type: TrackingLookupType;
  delivery_code: string;
  origin_city: string;
  destination_city: string;
  current_status: string;
  created_at: string;
  delivered_at: string | null;
  cancelled_at: string | null;
  milestones: PublicMilestone[];
}

export interface PublicTrackingError {
  is_valid: false;
  error: 'SHIPMENT_NOT_FOUND' | 'INVALID_OR_EXPIRED_TOKEN' | 'INVALID_CREDENTIAL_FORMAT' | 'EMPTY_QUERY' | string;
}

export type PublicTrackingResponse = PublicTrackingData | PublicTrackingError;
