/// Physical parcel size classification used for pricing.
///
/// Exact weight/dimension bounds are configured in the database
/// `parcel_size_tiers` table — not hard-coded here.
enum ParcelSize {
  /// Lightweight/compact items (e.g., documents, small accessories).
  small,

  /// Mid-range items (e.g., clothing bundles, electronics accessories).
  medium,

  /// Large/bulky items (e.g., bales of fabric, electronics).
  large;

  String get displayLabel {
    switch (this) {
      case ParcelSize.small:
        return 'Small';
      case ParcelSize.medium:
        return 'Medium';
      case ParcelSize.large:
        return 'Large';
    }
  }

  static ParcelSize? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return ParcelSize.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
