/// Status of an individual payment obligation.
enum PaymentStatus {
  /// This party has no payment responsibility for this shipment.
  notRequired,

  /// Payment is expected but not yet collected.
  pending,

  /// Physical cash or transfer has been recorded by Personnel.
  collected,

  /// Collection attempt failed.
  failed,

  /// Receiver refused to pay at delivery.
  refused;

  bool get isResolved =>
      this == PaymentStatus.collected ||
      this == PaymentStatus.notRequired;

  static PaymentStatus? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return PaymentStatus.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
