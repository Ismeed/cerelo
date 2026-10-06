/**
 * Cerelo API error codes matching the Dart CereloErrorCode enum.
 * All Cerelo Edge Functions return structured errors using these codes.
 * NEVER expose raw SQL errors or stack traces to users.
 */
export type CereloErrorCode =
  | 'VALIDATION_ERROR'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'INVALID_STATE_TRANSITION'
  | 'BUSINESS_RULE_VIOLATION'
  | 'CONFLICT'
  | 'PAYMENT_ALREADY_COLLECTED'
  | 'PAYMENT_AMOUNT_MISMATCH'
  | 'INTERNAL_ERROR'

export interface CereloApiError {
  code: CereloErrorCode
  message: string
  fieldErrors?: Record<string, string>
  requestId?: string
}

export function isCereloApiError(value: unknown): value is CereloApiError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    'message' in value
  )
}

/**
 * Formats an error for safe display to admin users.
 * Never exposes SQL errors, stack traces, or internal paths.
 */
export function formatSafeError(error: unknown): string {
  if (isCereloApiError(error)) {
    return error.message
  }
  if (error instanceof Error) {
    console.error('[Cerelo Admin Error]', error)
    return 'An unexpected error occurred. Please try again.'
  }
  return 'Something went wrong. Please try again.'
}
