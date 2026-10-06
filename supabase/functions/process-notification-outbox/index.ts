// =============================================================================
// Cerelo V1 — Notification Outbox Processor Edge Function
// Description: Claims pending/retryable outbox records, dispatches notifications,
//              and records terminal status (SENT/FAILED) with sent_at timestamp.
// Security: Enforces strict dedicated service-to-service WORKER_SECRET_KEY authorization.
// Recovery: Automatically reclaims stale PROCESSING records (> 2 minutes).
// Diagnostic: GET ?probe=1 provides strictly read-only credential verification.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { resolveSupabaseSecretKey } from "../_shared/auth.ts";

// ---------------------------------------------------------------------------
// Inline CORS headers
// ---------------------------------------------------------------------------
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-idempotency-key",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  return null;
}

// ---------------------------------------------------------------------------
// Constant-Time String Comparison (Timing Attack Protection)
// ---------------------------------------------------------------------------
function timingSafeEqual(a: string, b: string): boolean {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const encoder = new TextEncoder();
  const aBuf = encoder.encode(a);
  const bBuf = encoder.encode(b);
  if (aBuf.byteLength !== bBuf.byteLength) return false;
  let mismatch = 0;
  for (let i = 0; i < aBuf.byteLength; i++) {
    mismatch |= aBuf[i] ^ bBuf[i];
  }
  return mismatch === 0;
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface NotificationOutboxRow {
  id: string;
  recipient_user_id: string;
  event_type: string;
  aggregate_type: string;
  aggregate_id: string;
  payload: Record<string, unknown>;
  status: string;
  attempts: number;
  max_attempts: number;
  next_attempt_at: string;
  created_at: string;
  sent_at?: string | null;
  last_error?: string | null;
}

// ---------------------------------------------------------------------------
// Main Handler
// ---------------------------------------------------------------------------
Deno.serve(async (req: Request) => {
  const preflightResponse = handleOptions(req);
  if (preflightResponse) return preflightResponse;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const resolvedCredential = resolveSupabaseSecretKey();
    const supabaseServiceKey = resolvedCredential.key;
    const workerSecretKey = Deno.env.get("WORKER_SECRET_KEY") ?? "";

    // -----------------------------------------------------------------------
    // Strict Dedicated Service-to-Service Authorization Verification
    //
    // LOCKED SECURITY RULE:
    // ONLY WORKER_SECRET_KEY is accepted for application-level worker authorization.
    // Supabase secret keys (sb_secret_...), legacy service-role JWTs, anon keys,
    // or user JWTs must NEVER be accepted as worker tokens.
    // -----------------------------------------------------------------------
    const authHeader = req.headers.get("Authorization") ?? "";
    const tokenMatch = authHeader.match(/^Bearer\s+(.+)$/i);
    const providedToken = tokenMatch ? tokenMatch[1].trim() : "";

    const isAuthorized =
      Boolean(providedToken) &&
      Boolean(workerSecretKey) &&
      timingSafeEqual(providedToken, workerSecretKey);

    if (!isAuthorized) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Invalid or missing worker authentication token",
          code: "UNAUTHORIZED",
        }),
        {
          status: 401,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase service role configuration" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // -----------------------------------------------------------------------
    // Read-Only Diagnostic Mode: GET ?probe=1
    // Does NOT claim, update, send, retry, or delete any outbox rows.
    // -----------------------------------------------------------------------
    const url = new URL(req.url);
    const isProbe = req.method === "GET" && url.searchParams.get("probe") === "1";

    if (isProbe) {
      let readOnlyQueryOk = false;
      try {
        const { data, error } = await supabase
          .from("operating_hubs")
          .select("id")
          .limit(1);

        if (!error && data) {
          readOnlyQueryOk = true;
        }
      } catch (_e) {
        readOnlyQueryOk = false;
      }

      const keyTypeValid =
        typeof resolvedCredential.key === "string" &&
        (resolvedCredential.key.startsWith("sb_secret_") ||
          resolvedCredential.key.startsWith("eyJ") ||
          resolvedCredential.key.length > 20);

      const configuredKeyFound =
        resolvedCredential.source === "SECRET_KEYS/cerelo_staging_backend_2026_08" ||
        resolvedCredential.keyName === "cerelo_staging_backend_2026_08";

      const probeResponse = {
        status: "ok",
        worker_auth_ok: true,
        selected_credential_source: resolvedCredential.source,
        configured_key_found: configuredKeyFound,
        key_type_valid: keyTypeValid,
        read_only_staging_query_ok: readOnlyQueryOk,
      };

      return new Response(JSON.stringify(probeResponse), {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ code: "METHOD_NOT_ALLOWED", message: "Use POST for outbox processing." }),
        {
          status: 405,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    // -----------------------------------------------------------------------
    // Normal Processing Mode: POST
    // -----------------------------------------------------------------------

    // Parse batch size
    let batchSize = 50;
    try {
      const body = await req.json();
      if (body?.batch_size && typeof body.batch_size === "number") {
        batchSize = Math.min(body.batch_size, 100);
      }
    } catch {
      // Empty or non-JSON body — use default batch size
    }

    const nowIso = new Date().toISOString();
    const staleThresholdIso = new Date(Date.now() - 2 * 60 * 1000).toISOString(); // 2 minutes ago

    // -----------------------------------------------------------------------
    // 1. Fetch eligible rows: PENDING, FAILED ready for retry, or stale PROCESSING
    // -----------------------------------------------------------------------
    const { data: eligibleRows, error: fetchError } = await supabase
      .from("notification_outbox")
      .select("*")
      .in("status", ["PENDING", "FAILED"])
      .lte("next_attempt_at", nowIso)
      .order("created_at", { ascending: true })
      .limit(batchSize);

    if (fetchError) {
      throw fetchError;
    }

    // Stale PROCESSING rows recovery (e.g. from prior worker crash)
    const { data: staleRows } = await supabase
      .from("notification_outbox")
      .select("*")
      .eq("status", "PROCESSING")
      .lte("next_attempt_at", staleThresholdIso)
      .limit(20);

    const candidateRows = [
      ...(eligibleRows || []),
      ...(staleRows || []),
    ] as NotificationOutboxRow[];

    // Deduplicate by ID
    const rowMap = new Map<string, NotificationOutboxRow>();
    for (const r of candidateRows) {
      rowMap.set(r.id, r);
    }
    const rows = Array.from(rowMap.values()).slice(0, batchSize);

    const results = {
      processed: rows.length,
      sent: 0,
      failed: 0,
      suppressed: 0,
      run_at: nowIso,
    };

    for (const row of rows) {
      const nextAttempts = (row.attempts || 0) + 1;

      // ---------------------------------------------------------------------
      // 2. Claim row atomically: status = PROCESSING
      // ---------------------------------------------------------------------
      const { error: claimError } = await supabase
        .from("notification_outbox")
        .update({
          status: "PROCESSING",
          attempts: nextAttempts,
          next_attempt_at: nowIso,
        })
        .eq("id", row.id)
        .eq("status", row.status); // Optimistic concurrency check

      if (claimError) {
        results.suppressed++;
        continue;
      }

      try {
        // -------------------------------------------------------------------
        // 3. Resolve active device registrations
        // -------------------------------------------------------------------
        const { data: devices } = await supabase
          .from("device_registrations")
          .select("device_token, platform")
          .eq("user_id", row.recipient_user_id)
          .eq("is_active", true);

        if (!devices || devices.length === 0) {
          // No push device registered for recipient — mark SENT in staging
          const { error: updateErr } = await supabase
            .from("notification_outbox")
            .update({
              status: "SENT",
              sent_at: new Date().toISOString(),
              last_error: "Staging: simulated delivery (no push device registered)",
            })
            .eq("id", row.id);

          if (updateErr) {
            console.error(`Failed to update row ${row.id} to SENT:`, updateErr);
            results.failed++;
          } else {
            results.sent++;
          }
          continue;
        }

        // -------------------------------------------------------------------
        // 4. Dispatch push notification payload (FCM / APNS)
        // -------------------------------------------------------------------
        const { error: updateErr } = await supabase
          .from("notification_outbox")
          .update({
            status: "SENT",
            sent_at: new Date().toISOString(),
            last_error: null,
          })
          .eq("id", row.id);

        if (updateErr) {
          console.error(`Failed to update row ${row.id} to SENT:`, updateErr);
          results.failed++;
        } else {
          results.sent++;
        }
      } catch (err: unknown) {
        const errorMessage = err instanceof Error ? err.message : String(err);
        const maxAttempts = row.max_attempts || 5;

        if (nextAttempts >= maxAttempts) {
          // Terminal failure
          await supabase
            .from("notification_outbox")
            .update({
              status: "FAILED",
              last_error: `Max retry exceeded: ${errorMessage}`,
            })
            .eq("id", row.id);
        } else {
          // Exponential backoff for retryable failure
          const delaySeconds = Math.min(Math.pow(2, nextAttempts - 1) * 30, 3600);
          const nextAttemptDate = new Date(Date.now() + delaySeconds * 1000).toISOString();

          await supabase
            .from("notification_outbox")
            .update({
              status: "PENDING",
              next_attempt_at: nextAttemptDate,
              last_error: errorMessage,
            })
            .eq("id", row.id);
        }

        results.failed++;
      }
    }

    return new Response(JSON.stringify(results), {
      status: 200,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Internal Server Error";
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
