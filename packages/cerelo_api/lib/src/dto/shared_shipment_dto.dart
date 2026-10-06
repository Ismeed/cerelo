import 'package:cerelo_core/cerelo_core.dart';

/// DTO for the restricted public projection of a shared shipment.
///
/// Designed to be privacy-safe for shared tracking links:
/// - Masks sender name to first name only.
/// - Masks receiver phone number.
/// - Shows only customer-safe status and parcel summary.
/// - Never exposes internal IDs, personnel, or batch details.
class SharedShipmentDto {
  const SharedShipmentDto({
    required this.shipmentId,
    required this.originCity,
    required this.destinationCity,
    required this.status,
    required this.senderDisplayName,
    required this.receiverNameSnapshot,
    required this.receiverPhoneMasked,
    required this.receiverDeliveryAddress,
    required this.categoryDescription,
    required this.paymentMode,
    required this.receiverExpectedAmount,
    required this.alreadyLinked,
    required this.isIntendedReceiver,
    required this.createdAt,
  });

  final String shipmentId;
  final String originCity;
  final String destinationCity;
  final ShipmentStatus status;
  final String senderDisplayName;
  final String receiverNameSnapshot;
  final String receiverPhoneMasked;
  final String receiverDeliveryAddress;
  final String categoryDescription;
  final PaymentMode paymentMode;
  final Money receiverExpectedAmount;
  final bool alreadyLinked;
  final bool isIntendedReceiver;
  final DateTime createdAt;

  String get routeDisplay => '$originCity → $destinationCity';

  factory SharedShipmentDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_status'] as String? ?? 'REQUESTED';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.requested;

    final paymentModeStr = json['payment_mode'] as String? ?? 'SENDER_PAYS';
    final paymentMode = PaymentMode.fromString(paymentModeStr.toLowerCase()) ??
        PaymentMode.senderPays;

    final expectedKobo =
        (json['receiver_expected_amount'] as num?)?.toInt() ?? 0;

    return SharedShipmentDto(
      shipmentId: json['shipment_id'] as String? ?? '',
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      status: status,
      senderDisplayName: json['sender_display_name'] as String? ?? 'Sender',
      receiverNameSnapshot: json['receiver_name_snapshot'] as String? ?? '',
      receiverPhoneMasked: json['receiver_phone_masked'] as String? ?? '***',
      receiverDeliveryAddress:
          json['receiver_delivery_address'] as String? ?? '',
      categoryDescription:
          json['category_description'] as String? ?? 'General Package',
      paymentMode: paymentMode,
      receiverExpectedAmount: Money.fromKobo(expectedKobo),
      alreadyLinked: json['already_linked'] as bool? ?? false,
      isIntendedReceiver: json['is_intended_receiver'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

/// DTO for a generated shipment share link.
class ShareLinkDto {
  const ShareLinkDto({
    required this.token,
    required this.expiresAt,
    required this.shareUrl,
  });

  final String token;
  final DateTime expiresAt;
  final String shareUrl;

  factory ShareLinkDto.fromJson(Map<String, dynamic> json) {
    return ShareLinkDto(
      token: json['token'] as String? ?? '',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      shareUrl: json['share_url'] as String? ?? '',
    );
  }
}
