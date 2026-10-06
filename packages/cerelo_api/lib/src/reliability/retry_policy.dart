import 'dart:math';

/// Classification of operational and technical failures.
enum FailureCategory {
  /// Temporary network drop or provider 5xx; safe to retry with backoff.
  transient,

  /// Validation failure, invalid state, or authorization rejection; do NOT retry.
  permanent,

  /// Mutation response timed out or was interrupted; requires status reconciliation
  /// using the exact same idempotency key.
  unknownOutcome,
}

/// Centralized retry and error classification policy for Cerelo.
class RetryPolicy {
  /// Evaluates an exception and classifies its retry safety.
  static FailureCategory classify(dynamic error) {
    if (error == null) return FailureCategory.permanent;

    final str = error.toString().toLowerCase();

    // Check for unknown outcome / timeout on mutation
    if (str.contains('timeout') || str.contains('deadline') || str.contains('wsarecv')) {
      return FailureCategory.unknownOutcome;
    }

    // Check for transient network issues
    if (str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('502') ||
        str.contains('503') ||
        str.contains('504')) {
      return FailureCategory.transient;
    }

    // Default to permanent for business rule / auth / schema errors
    return FailureCategory.permanent;
  }

  /// Calculates jittered exponential backoff for transient retries.
  static Duration calculateBackoff(
    int attempt, {
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
  }) {
    if (attempt <= 0) return baseDelay;

    final exponential = baseDelay.inMilliseconds * pow(2, attempt - 1);
    final capped = min(exponential.toInt(), maxDelay.inMilliseconds);
    // Add 10% jitter
    final randomJitter = Random().nextInt((capped * 0.1).toInt() + 1);

    return Duration(milliseconds: capped + randomJitter);
  }
}
