import 'package:meta/meta.dart';

/// A non-sequential, human-readable Cerelo shipment reference code.
///
/// Format: CRL-XXXX-XXXX (e.g., CRL-8F2K-9P3N).
///
/// SECURITY:
/// - Delivery Codes are NOT proof of identity.
/// - Knowing a Delivery Code alone does NOT grant access to shipment details.
/// - Public lookup is rate-limited server-side (5 requests/min per IP).
/// - Never use sequential integers as Delivery Codes.
@immutable
class DeliveryCode {
  const DeliveryCode._(this.value);

  final String value;

  /// Validates and wraps a Delivery Code string.
  static DeliveryCode? tryParse(String raw) {
    final cleaned = raw.trim().toUpperCase();
    if (_isValidFormat(cleaned)) {
      return DeliveryCode._(cleaned);
    }
    return null;
  }

  /// Regular expression for CRL-XXXX-XXXX format.
  static final _pattern = RegExp(r'^CRL-[A-Z0-9]{4}-[A-Z0-9]{4}$');

  static bool _isValidFormat(String value) => _pattern.hasMatch(value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryCode && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
