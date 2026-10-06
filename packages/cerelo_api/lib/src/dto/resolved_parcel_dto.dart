import 'package:cerelo_core/cerelo_core.dart';

/// DTO for an operational parcel resolved via Parcel QR scan or manual Delivery Code lookup.
class ResolvedParcelDto {
  const ResolvedParcelDto({
    required this.parcelId,
    required this.shipmentId,
    required this.deliveryCode,
    required this.parcelQrToken,
    required this.currentParcelState,
    required this.currentStatus,
    required this.originCity,
    required this.destinationCity,
    required this.senderName,
    required this.receiverName,
    required this.confirmedSizeCode,
    required this.confirmedSizeName,
    required this.categoryDescription,
    required this.finalPrice,
    required this.paymentMode,
    required this.isHubReceived,
    required this.isReadyForBatch,
  });

  final String parcelId;
  final String shipmentId;
  final String deliveryCode;
  final String parcelQrToken;
  final ParcelState currentParcelState;
  final ShipmentStatus currentStatus;
  final String originCity;
  final String destinationCity;
  final String senderName;
  final String receiverName;
  final String confirmedSizeCode;
  final String confirmedSizeName;
  final String categoryDescription;
  final Money finalPrice;
  final PaymentMode paymentMode;
  final bool isHubReceived;
  final bool isReadyForBatch;

  String get routeDisplay => '$originCity → $destinationCity';

  factory ResolvedParcelDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_status'] as String? ?? 'REQUESTED';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.requested;

    final parcelStateStr =
        json['current_parcel_state'] as String? ?? 'IN_CERELO_CUSTODY';
    final parcelState =
        ParcelState.fromString(parcelStateStr.toLowerCase()) ??
            ParcelState.inCereloCustody;

    final paymentModeStr = json['payment_mode'] as String? ?? 'SENDER_PAYS';
    final paymentMode =
        PaymentMode.fromString(paymentModeStr.toLowerCase()) ??
            PaymentMode.senderPays;

    final priceKobo = (json['final_price_amount'] as num?)?.toInt() ?? 0;

    return ResolvedParcelDto(
      parcelId: json['parcel_id'] as String? ?? '',
      shipmentId: json['shipment_id'] as String? ?? '',
      deliveryCode: json['delivery_code'] as String? ?? 'CRL-0000-0000',
      parcelQrToken: json['parcel_qr_token'] as String? ?? '',
      currentParcelState: parcelState,
      currentStatus: status,
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      senderName: json['sender_name'] as String? ?? 'Sender',
      receiverName: json['receiver_name'] as String? ?? 'Receiver',
      confirmedSizeCode: json['confirmed_size_code'] as String? ?? 'MEDIUM',
      confirmedSizeName:
          json['confirmed_size_name'] as String? ?? 'Medium Package',
      categoryDescription:
          json['category_description'] as String? ?? 'General Goods',
      finalPrice: Money.fromKobo(priceKobo),
      paymentMode: paymentMode,
      isHubReceived: json['is_hub_received'] as bool? ?? false,
      isReadyForBatch: json['is_ready_for_batch'] as bool? ?? false,
    );
  }
}

/// DTO for parcels staged at origin hub ready for batch consolidation.
class ReadyForBatchParcelDto {
  const ReadyForBatchParcelDto({
    required this.parcelId,
    required this.shipmentId,
    required this.deliveryCode,
    required this.parcelQrToken,
    required this.originCity,
    required this.destinationCity,
    required this.confirmedSizeCode,
    required this.confirmedSizeName,
    required this.categoryDescription,
    required this.createdAt,
  });

  final String parcelId;
  final String shipmentId;
  final String deliveryCode;
  final String parcelQrToken;
  final String originCity;
  final String destinationCity;
  final String confirmedSizeCode;
  final String confirmedSizeName;
  final String categoryDescription;
  final DateTime createdAt;

  String get routeDisplay => '$originCity → $destinationCity';

  factory ReadyForBatchParcelDto.fromJson(Map<String, dynamic> json) {
    return ReadyForBatchParcelDto(
      parcelId: json['parcel_id'] as String? ?? '',
      shipmentId: json['shipment_id'] as String? ?? '',
      deliveryCode: json['delivery_code'] as String? ?? 'CRL-0000-0000',
      parcelQrToken: json['parcel_qr_token'] as String? ?? '',
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      confirmedSizeCode: json['confirmed_size_code'] as String? ?? 'MEDIUM',
      confirmedSizeName:
          json['confirmed_size_name'] as String? ?? 'Medium Package',
      categoryDescription:
          json['category_description'] as String? ?? 'General Goods',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
