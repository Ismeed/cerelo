import 'package:cerelo_core/cerelo_core.dart';

/// DTO for an operational final-mile doorstep delivery task in the Personnel queue.
class DeliveryTaskDto {
  const DeliveryTaskDto({
    required this.shipmentId,
    required this.parcelId,
    required this.deliveryCode,
    required this.parcelQrToken,
    required this.status,
    required this.originCity,
    required this.destinationCity,
    this.originHubId,
    this.destinationHubId,
    this.assignedDeliveryPersonnelId,
    this.isClaimedByMe = false,
    this.isAvailable = false,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverDeliveryAddress,
    this.landmark,
    this.deliveryInstructions,
    required this.confirmedSizeCode,
    required this.confirmedSizeName,
    required this.categoryDescription,
    required this.paymentMode,
    required this.finalPrice,
    required this.receiverPaymentStatus,
    required this.receiverDueAmount,
    required this.createdAt,
  });

  final String shipmentId;
  final String parcelId;
  final String deliveryCode;
  final String parcelQrToken;
  final ShipmentStatus status;
  final String originCity;
  final String destinationCity;
  final String? originHubId;
  final String? destinationHubId;
  final String? assignedDeliveryPersonnelId;
  final bool isClaimedByMe;
  final bool isAvailable;
  final String senderName;
  final String senderPhone;
  final String receiverName;
  final String receiverPhone;
  final String receiverDeliveryAddress;
  final String? landmark;
  final String? deliveryInstructions;
  final String confirmedSizeCode;
  final String confirmedSizeName;
  final String categoryDescription;
  final PaymentMode paymentMode;
  final Money finalPrice;
  final PaymentStatus receiverPaymentStatus;
  final Money receiverDueAmount;
  final DateTime createdAt;

  String get routeDisplay => '$originCity → $destinationCity';

  bool get requiresReceiverPayment => receiverDueAmount.kobo > 0;

  factory DeliveryTaskDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_status'] as String? ?? 'ARRIVED_DESTINATION';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.arrivedDestination;

    final paymentModeStr = json['payment_mode'] as String? ?? 'SENDER_PAYS';
    final paymentMode =
        PaymentMode.fromString(paymentModeStr.toLowerCase()) ??
            PaymentMode.senderPays;

    final payStatusStr = json['receiver_payment_status'] as String? ?? 'NOT_REQUIRED';
    final receiverPaymentStatus =
        PaymentStatus.fromString(payStatusStr.toLowerCase()) ??
            PaymentStatus.notRequired;

    final priceKobo = (json['final_price_amount'] as num?)?.toInt() ?? 0;
    final dueKobo = (json['receiver_due_amount'] as num?)?.toInt() ?? 0;

    return DeliveryTaskDto(
      shipmentId: json['shipment_id'] as String? ?? '',
      parcelId: json['parcel_id'] as String? ?? '',
      deliveryCode: json['delivery_code'] as String? ?? 'CRL-0000-0000',
      parcelQrToken: json['parcel_qr_token'] as String? ?? '',
      status: status,
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      originHubId: json['origin_hub_id'] as String?,
      destinationHubId: json['destination_hub_id'] as String?,
      assignedDeliveryPersonnelId: json['assigned_delivery_personnel_id'] as String?,
      isClaimedByMe: json['is_claimed_by_me'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? (json['assigned_delivery_personnel_id'] == null && status == ShipmentStatus.arrivedDestination),
      senderName: json['sender_name'] as String? ?? 'Sender',
      senderPhone: json['sender_phone'] as String? ?? '',
      receiverName: json['receiver_name'] as String? ?? 'Receiver',
      receiverPhone: json['receiver_phone'] as String? ?? '',
      receiverDeliveryAddress: json['receiver_delivery_address'] as String? ?? '',
      landmark: json['landmark'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      confirmedSizeCode: json['confirmed_size_code'] as String? ?? 'MEDIUM',
      confirmedSizeName:
          json['confirmed_size_name'] as String? ?? 'Medium Package',
      categoryDescription:
          json['category_description'] as String? ?? 'General Goods',
      paymentMode: paymentMode,
      finalPrice: Money.fromKobo(priceKobo),
      receiverPaymentStatus: receiverPaymentStatus,
      receiverDueAmount: Money.fromKobo(dueKobo),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_id': shipmentId,
      'parcel_id': parcelId,
      'delivery_code': deliveryCode,
      'parcel_qr_token': parcelQrToken,
      'current_status': status.name.toUpperCase(),
      'origin_city': originCity,
      'destination_city': destinationCity,
      'origin_hub_id': originHubId,
      'destination_hub_id': destinationHubId,
      'assigned_delivery_personnel_id': assignedDeliveryPersonnelId,
      'is_claimed_by_me': isClaimedByMe,
      'is_available': isAvailable,
      'sender_name': senderName,
      'sender_phone': senderPhone,
      'receiver_name': receiverName,
      'receiver_phone': receiverPhone,
      'receiver_delivery_address': receiverDeliveryAddress,
      'landmark': landmark,
      'delivery_instructions': deliveryInstructions,
      'confirmed_size_code': confirmedSizeCode,
      'confirmed_size_name': confirmedSizeName,
      'category_description': categoryDescription,
      'payment_mode': paymentMode.name.toUpperCase(),
      'final_price_amount': finalPrice.kobo,
      'receiver_payment_status': receiverPaymentStatus.name.toUpperCase(),
      'receiver_due_amount': receiverDueAmount.kobo,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
