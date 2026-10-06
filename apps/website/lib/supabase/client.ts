import { createClient, SupabaseClient } from '@supabase/supabase-js';
import type { PublicTrackingResponse } from '@/lib/types/tracking';

let supabaseBrowserClient: SupabaseClient | null = null;

export function getSupabaseBrowserClient(): SupabaseClient {
  if (supabaseBrowserClient) return supabaseBrowserClient;

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !publishableKey) {
    throw new Error('Supabase environment variables NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY are missing.');
  }

  supabaseBrowserClient = createClient(supabaseUrl, publishableKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  return supabaseBrowserClient;
}

/**
 * Executes server-authoritative public tracking RPC on Supabase.
 * Strictly uses publishable key and get_public_shipment_tracking RPC.
 */
export async function fetchPublicShipmentTracking(
  query: string
): Promise<PublicTrackingResponse> {
  const client = getSupabaseBrowserClient();
  const trimmed = query.trim();

  if (!trimmed) {
    return { is_valid: false, error: 'EMPTY_QUERY' };
  }

  const { data, error } = await client.rpc('get_public_shipment_tracking', {
    p_tracking_query: trimmed,
  });

  if (error) {
    console.error('Tracking query error:', error.message);
    throw new Error('Unable to complete tracking lookup. Please try again.');
  }

  return data as PublicTrackingResponse;
}
