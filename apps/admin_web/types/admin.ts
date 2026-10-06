export interface AdminOverviewMetrics {
  requests_awaiting_pickup: number
  parcels_in_custody: number
  origin_hub_staged: number
  draft_batches: number
  confirmed_batches: number
  in_transit_batches: number
  destination_received_batches: number
  ready_for_delivery: number
  out_for_delivery: number
  delivered_today: number
  open_incidents: number
  total_collected_today_kobo: number
  kano_to_katsina_active_shipments: number
  katsina_to_kano_active_shipments: number
}

export interface AdminShipmentSummary {
  id: string
  delivery_code: string
  current_status: string
  origin_city: string
  destination_city: string
  sender_name: string
  sender_phone: string
  receiver_name: string
  receiver_phone: string
  final_price_amount: number
  payment_mode: string
  created_at: string
  delivered_at?: string | null
}

export interface AdminPersonnelSummary {
  id: string
  user_id: string
  full_name: string
  phone_number: string
  employee_reference: string
  is_active: boolean
  operating_hub_id: string
  operating_hub_name: string
  created_at: string
}

export interface OperatingHub {
  id: string
  code: string
  name: string
  city: string
}

export interface PersonnelProvisionInput {
  fullName: string
  email: string
  phoneNumber: string
  employeeReference: string
  operatingHubId: string
}

export interface AdminBatchSummary {
  id: string
  batch_number: string
  origin_hub_name: string
  destination_hub_name: string
  status: string
  manifest_count: number
  batch_qr_token?: string | null
  created_at: string
  departed_at?: string | null
  received_at?: string | null
}

export interface AdminIncidentSummary {
  id: string
  resource_type: string
  resource_id: string
  category: string
  status: 'OPEN' | 'RESOLVED'
  severity: string
  notes: string
  resolution_notes?: string | null
  created_at: string
  resolved_at?: string | null
}

export interface AdminAuditLog {
  id: string
  actor_email: string
  action: string
  aggregate_type: string
  aggregate_id: string
  reason: string
  before_state: Record<string, unknown> | null
  after_state: Record<string, unknown> | null
  created_at: string
}

export interface AdminConfiguration {
  corridors: Array<{
    id: string
    code: string
    name: string
    origin_city: string
    destination_city: string
    is_active: boolean
  }>
  size_tiers: Array<{
    id: string
    code: string
    name: string
    description: string
  }>
  pricing_rules: Array<{
    id: string
    corridor_code: string
    size_tier_code: string
    base_price_amount: number
    is_active: boolean
  }>
}
