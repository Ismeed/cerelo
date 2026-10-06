/// Structured error codes returned by Cerelo backend RPCs and Edge Functions.
///
/// Clients must handle these codes to show appropriate user messages.
/// NEVER expose raw SQL errors, stack traces, or internal paths to clients.
enum CereloErrorCode {
  // ─── Client / Request Errors ────────────────────────────────────────────

  /// One or more request fields failed validation.
  validationError,

  /// Request is not authenticated.
  unauthenticated,

  /// Authenticated actor does not have permission for this action.
  forbidden,

  /// The requested resource does not exist.
  notFound,

  // ─── State Machine Errors ───────────────────────────────────────────────

  /// The requested state transition is not valid from the current state.
  invalidStateTransition,

  /// A business rule precondition was not met.
  businessRuleViolation,

  /// A concurrent request has already processed this action.
  conflict,

  // ─── Payment Errors ─────────────────────────────────────────────────────

  /// Payment obligation has already been collected.
  paymentAlreadyCollected,

  /// The submitted payment amount does not match the expected obligation.
  paymentAmountMismatch,

  // ─── Server Errors ──────────────────────────────────────────────────────

  /// An unexpected internal server error occurred.
  internalError;

  /// HTTP-friendly short code string (used in API response bodies).
  String get code {
    switch (this) {
      case CereloErrorCode.validationError:
        return 'VALIDATION_ERROR';
      case CereloErrorCode.unauthenticated:
        return 'UNAUTHENTICATED';
      case CereloErrorCode.forbidden:
        return 'FORBIDDEN';
      case CereloErrorCode.notFound:
        return 'NOT_FOUND';
      case CereloErrorCode.invalidStateTransition:
        return 'INVALID_STATE_TRANSITION';
      case CereloErrorCode.businessRuleViolation:
        return 'BUSINESS_RULE_VIOLATION';
      case CereloErrorCode.conflict:
        return 'CONFLICT';
      case CereloErrorCode.paymentAlreadyCollected:
        return 'PAYMENT_ALREADY_COLLECTED';
      case CereloErrorCode.paymentAmountMismatch:
        return 'PAYMENT_AMOUNT_MISMATCH';
      case CereloErrorCode.internalError:
        return 'INTERNAL_ERROR';
    }
  }

  static CereloErrorCode? fromCode(String? code) {
    if (code == null) return null;
    return CereloErrorCode.values.where((e) => e.code == code).firstOrNull;
  }
}

/// A domain error surfaced to the application from the server.
class CereloException implements Exception {
  const CereloException({
    required this.code,
    required this.message,
    this.fieldErrors,
  });

  final CereloErrorCode code;
  final String message;

  /// Field-level validation errors (key: field name, value: error message).
  final Map<String, String>? fieldErrors;

  @override
  String toString() => 'CereloException(${code.code}): $message';
}
