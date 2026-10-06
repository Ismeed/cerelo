/// How a shipment's total fee is split between Sender and Receiver.
enum PaymentMode {
  /// Sender pays 100% at pickup.
  senderPays,

  /// Receiver pays 100% at doorstep delivery.
  receiverPays,

  /// Fee is split: Sender pays a portion at pickup,
  /// Receiver pays the remainder at delivery.
  splitPayment;

  String get displayLabel {
    switch (this) {
      case PaymentMode.senderPays:
        return 'Sender Pays';
      case PaymentMode.receiverPays:
        return 'Receiver Pays';
      case PaymentMode.splitPayment:
        return 'Split Payment';
    }
  }

  static PaymentMode? fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return PaymentMode.values.where((e) => e.name.toLowerCase() == cleaned).firstOrNull;
  }
}
