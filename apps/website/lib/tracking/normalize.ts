/**
 * Normalizes whatever a user pastes into the tracking box into something the
 * `get_public_shipment_tracking` RPC will actually accept.
 *
 * The RPC only recognises a bare delivery code (`CRL` + 8 chars from the
 * ambiguity-free alphabet, separators stripped) or a 32-char share token. But
 * everything the customer app puts on the clipboard is richer than that: the
 * share sheet copies a full `/track/CRL-XXXX-XXXX` URL, and the "share message"
 * action copies an entire WhatsApp sentence with that URL embedded in it.
 * Pasting either used to fail lookup even though the code was sitting right
 * there in the text.
 *
 * So: pull the code (or token) out of a URL, a query parameter, or free prose,
 * and hand back a canonical form. Anything we can't recognise is returned
 * trimmed-but-untouched, so the RPC still owns the final validity verdict and
 * the user still gets a real error for a genuinely bad code.
 */

/** Delivery code alphabet excludes 0/1/I/O, matching the generator and the RPC. */
const DELIVERY_CODE_PATTERN = /CRL[-\s]?[2-9A-HJ-NP-Z]{4}[-\s]?[2-9A-HJ-NP-Z]{4}/;

/** Share tokens are 32 hex characters. */
const SHARE_TOKEN_PATTERN = /\b[0-9a-f]{32}\b/i;

function safeDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

export function normalizeTrackingQuery(raw: string): string {
  const input = (raw ?? '').trim();
  if (!input) return '';

  // A pasted URL may carry the value in ?code= / ?token=; prefer that when present.
  const paramMatch = input.match(/[?&](?:code|token)=([^&\s]+)/i);
  const haystack = paramMatch ? safeDecode(paramMatch[1]) : input;

  const token = haystack.match(SHARE_TOKEN_PATTERN);
  if (token) return token[0].toLowerCase();

  const code = haystack.toUpperCase().match(DELIVERY_CODE_PATTERN);
  if (code) {
    const compact = code[0].replace(/[-\s]/g, '');
    return `${compact.slice(0, 3)}-${compact.slice(3, 7)}-${compact.slice(7, 11)}`;
  }

  return input;
}
