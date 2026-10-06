import 'package:cerelo_core/cerelo_core.dart';

/// Represents a structured API error from a Cerelo backend response.
///
/// All Cerelo Edge Functions return errors in this standardized format.
/// Clients should handle [CereloApiError] to show user-friendly messages.
///
/// SECURITY: Raw SQL errors, stack traces, and internal paths are never
/// included in the error body returned to clients.
class CereloApiError implements Exception {
  const CereloApiError({
    required this.code,
    required this.message,
    this.fieldErrors,
    this.requestId,
  });

  /// Structured error code (maps to [CereloErrorCode]).
  final CereloErrorCode code;

  /// Safe, user-displayable error message.
  final String message;

  /// Field-level validation errors for form display.
  final Map<String, String>? fieldErrors;

  /// Request correlation ID for debugging (safe to log/display).
  final String? requestId;

  /// Attempts to parse a CereloApiError from a JSON response body.
  static CereloApiError? tryFromJson(Map<String, dynamic> json) {
    final codeStr = json['code'] as String?;
    final message = json['message'] as String?;
    if (codeStr == null || message == null) return null;

    final code = CereloErrorCode.fromCode(codeStr);
    if (code == null) return null;

    final fieldErrorsRaw = json['field_errors'] as Map<String, dynamic>?;
    final fieldErrors = fieldErrorsRaw?.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    return CereloApiError(
      code: code,
      message: message,
      fieldErrors: fieldErrors,
      requestId: json['request_id'] as String?,
    );
  }

  /// Returns a generic internal error when parsing fails.
  static const internal = CereloApiError(
    code: CereloErrorCode.internalError,
    message: 'Something went wrong. Please try again.',
  );

  @override
  String toString() => 'CereloApiError(${code.code}): $message';
}
