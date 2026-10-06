import 'package:meta/meta.dart';

/// Represents a validated and normalized Nigerian phone number in E.164 format.
///
/// Nigerian mobile numbers begin with +234 followed by a 10-digit local number.
///
/// SECURITY: Phone numbers are PII. They must not be:
/// - Embedded in QR code payloads
/// - Shown in public shared tracking views
/// - Logged in plain text unnecessarily
@immutable
class PhoneNumber {
  const PhoneNumber._(this.e164);

  /// E.164 formatted phone number (e.g., +2348012345678).
  final String e164;

  /// Attempts to parse and normalize a Nigerian phone number to E.164 format.
  ///
  /// Accepts:
  ///   - +2348012345678
  ///   - 2348012345678
  ///   - 08012345678 (local format)
  ///   - 8012345678
  static PhoneNumber? tryParse(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    String normalized;

    if (cleaned.startsWith('+234')) {
      normalized = cleaned;
    } else if (cleaned.startsWith('234')) {
      normalized = '+$cleaned';
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      normalized = '+234${cleaned.substring(1)}';
    } else if (cleaned.length == 10) {
      normalized = '+234$cleaned';
    } else {
      return null;
    }

    if (!_isValidE164Nigerian(normalized)) return null;
    return PhoneNumber._(normalized);
  }

  static final _e164Pattern = RegExp(r'^\+234[789][01]\d{8}$');

  static bool _isValidE164Nigerian(String value) =>
      _e164Pattern.hasMatch(value);

  /// Returns a masked version safe for display in shared views.
  /// Example: +2348012345678 → +234 801 ***5678
  String get masked {
    if (e164.length < 8) return '***';
    return '${e164.substring(0, 8)}***${e164.substring(e164.length - 4)}';
  }

  @override
  String toString() => e164;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PhoneNumber && other.e164 == e164;

  @override
  int get hashCode => e164.hashCode;
}
