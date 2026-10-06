import 'package:meta/meta.dart';

/// Represents a Nigerian Naira monetary amount as an integer number of kobo.
///
/// IMPORTANT: All monetary values in Cerelo are stored and computed as
/// non-negative integers (kobo/minor units) to avoid floating-point errors.
/// Never use double/float for currency calculations.
///
/// Example:
///   Money.fromNaira(3000)   // ₦3,000.00
///   Money.fromKobo(300000)  // ₦3,000.00
@immutable
class Money {
  /// Creates a Money value from kobo (minor units).
  const Money.fromKobo(this._kobo) : assert(_kobo >= 0, 'Money cannot be negative');

  /// Creates a Money value from whole Naira.
  const Money.fromNaira(int naira) : this.fromKobo(naira * 100);

  final int _kobo;

  /// Value in kobo (minor units) — use this for storage and API calls.
  int get kobo => _kobo;

  /// Value in Naira (for display purposes only).
  double get naira => _kobo / 100.0;

  /// Formats as Nigerian Naira display string.
  String get formatted {
    final wholeNaira = _kobo ~/ 100;
    final koboRemainder = _kobo % 100;
    final nairaStr = _formatWithCommas(wholeNaira);
    if (koboRemainder == 0) {
      return '₦$nairaStr';
    }
    return '₦$nairaStr.${koboRemainder.toString().padLeft(2, '0')}';
  }

  static String _formatWithCommas(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    final offset = str.length % 3;
    for (var i = 0; i < str.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Money operator +(Money other) => Money.fromKobo(_kobo + other._kobo);
  Money operator -(Money other) {
    final result = _kobo - other._kobo;
    if (result < 0) throw ArgumentError('Money subtraction resulted in negative value');
    return Money.fromKobo(result);
  }

  bool operator >(Money other) => _kobo > other._kobo;
  bool operator <(Money other) => _kobo < other._kobo;
  bool operator >=(Money other) => _kobo >= other._kobo;
  bool operator <=(Money other) => _kobo <= other._kobo;

  static const zero = Money.fromKobo(0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && other._kobo == _kobo;

  @override
  int get hashCode => _kobo.hashCode;

  @override
  String toString() => formatted;
}
