import 'package:cerelo_core/cerelo_core.dart';

/// DTO for an operational pickup task in the Personnel queue.
class PickupTaskDto {
  const PickupTaskDto({
    required this.id,
    this.deliveryCode,
    required this.status,
    required this.originCity,
    required this.destinationCity,
    this.originHubId,
    this.destinationHubId,
    this.assignedPickupPersonnelId,
    this.isClaimedByMe = false,
    this.isAvailable = false,
    required this.senderName,
    required this.senderPhone,
    required this.senderPickupAddress,
    this.landmark,
    this.deliveryInstructions,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverDeliveryAddress,
    required this.declaredSize,
    required this.declaredSizeName,
    required this.categoryDescription,
    required this.paymentMode,
    required this.quotedPrice,
    required this.finalPrice,
    required this.createdAt,
  });

  final String id;
  final String? deliveryCode;
  final ShipmentStatus status;
  final String originCity;
  final String destinationCity;
  final String? originHubId;
  final String? destinationHubId;
  final String? assignedPickupPersonnelId;
  final bool isClaimedByMe;
  final bool isAvailable;
  final String senderName;
  final String senderPhone;
  final String senderPickupAddress;
  final String? landmark;
  final String? deliveryInstructions;
  final String receiverName;
  final String receiverPhone;
  final String receiverDeliveryAddress;
  final ParcelSize declaredSize;
  final String declaredSizeName;
  final String categoryDescription;
  final PaymentMode paymentMode;
  final Money quotedPrice;
  final Money finalPrice;
  final DateTime createdAt;

  String get routeDisplay => '$originCity → $destinationCity';

  PickupTaskDto copyWith({
    String? id,
    String? deliveryCode,
    ShipmentStatus? status,
    String? originCity,
    String? destinationCity,
    String? originHubId,
    String? destinationHubId,
    String? assignedPickupPersonnelId,
    bool? isClaimedByMe,
    bool? isAvailable,
    String? senderName,
    String? senderPhone,
    String? senderPickupAddress,
    String? landmark,
    String? deliveryInstructions,
    String? receiverName,
    String? receiverPhone,
    String? receiverDeliveryAddress,
    ParcelSize? declaredSize,
    String? declaredSizeName,
    String? categoryDescription,
    PaymentMode? paymentMode,
    Money? quotedPrice,
    Money? finalPrice,
    DateTime? createdAt,
  }) {
    return PickupTaskDto(
      id: id ?? this.id,
      deliveryCode: deliveryCode ?? this.deliveryCode,
      status: status ?? this.status,
      originCity: originCity ?? this.originCity,
      destinationCity: destinationCity ?? this.destinationCity,
      originHubId: originHubId ?? this.originHubId,
      destinationHubId: destinationHubId ?? this.destinationHubId,
      assignedPickupPersonnelId:
          assignedPickupPersonnelId ?? this.assignedPickupPersonnelId,
      isClaimedByMe: isClaimedByMe ?? this.isClaimedByMe,
      isAvailable: isAvailable ?? this.isAvailable,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      senderPickupAddress: senderPickupAddress ?? this.senderPickupAddress,
      landmark: landmark ?? this.landmark,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverDeliveryAddress:
          receiverDeliveryAddress ?? this.receiverDeliveryAddress,
      declaredSize: declaredSize ?? this.declaredSize,
      declaredSizeName: declaredSizeName ?? this.declaredSizeName,
      categoryDescription: categoryDescription ?? this.categoryDescription,
      paymentMode: paymentMode ?? this.paymentMode,
      quotedPrice: quotedPrice ?? this.quotedPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PickupTaskDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_status'] as String? ?? 'REQUESTED';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.requested;

    final declaredSizeStr = json['declared_size_code'] as String? ?? 'MEDIUM';
    final declaredSize =
        ParcelSize.fromString(declaredSizeStr.toLowerCase()) ??
            ParcelSize.medium;

    final paymentModeStr = json['payment_mode'] as String? ?? 'SENDER_PAYS';
    final paymentMode =
        PaymentMode.fromString(paymentModeStr.toLowerCase()) ??
            PaymentMode.senderPays;

    final quotedKobo = (json['quoted_price_amount'] as num?)?.toInt() ?? 0;
    final finalKobo = (json['final_price_amount'] as num?)?.toInt() ?? quotedKobo;

    return PickupTaskDto(
      id: json['id'] as String? ?? '',
      deliveryCode: json['delivery_code'] as String?,
      status: status,
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      originHubId: json['origin_hub_id'] as String?,
      destinationHubId: json['destination_hub_id'] as String?,
      assignedPickupPersonnelId: json['assigned_pickup_personnel_id'] as String?,
      isClaimedByMe: json['is_claimed_by_me'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? (json['assigned_pickup_personnel_id'] == null && status == ShipmentStatus.requested),
      senderName: json['sender_name_snapshot'] as String? ?? 'Sender',
      senderPhone: json['sender_phone_snapshot'] as String? ?? '',
      senderPickupAddress:
          json['sender_pickup_address_snapshot'] as String? ?? '',
      landmark: json['landmark'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      receiverName: json['receiver_name_snapshot'] as String? ?? 'Receiver',
      receiverPhone: json['receiver_phone_snapshot'] as String? ?? '',
      receiverDeliveryAddress:
          json['receiver_delivery_address_snapshot'] as String? ?? '',
      declaredSize: declaredSize,
      declaredSizeName:
          json['declared_size_name'] as String? ?? declaredSize.displayLabel,
      categoryDescription:
          json['category_description'] as String? ?? 'General Goods',
      paymentMode: paymentMode,
      quotedPrice: Money.fromKobo(quotedKobo),
      finalPrice: Money.fromKobo(finalKobo),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_code': deliveryCode,
      'current_status': status.name.toUpperCase(),
      'origin_city': originCity,
      'destination_city': destinationCity,
      'origin_hub_id': originHubId,
      'destination_hub_id': destinationHubId,
      'assigned_pickup_personnel_id': assignedPickupPersonnelId,
      'is_claimed_by_me': isClaimedByMe,
      'is_available': isAvailable,
      'sender_name_snapshot': senderName,
      'sender_phone_snapshot': senderPhone,
      'sender_pickup_address_snapshot': senderPickupAddress,
      'landmark': landmark,
      'delivery_instructions': deliveryInstructions,
      'receiver_name_snapshot': receiverName,
      'receiver_phone_snapshot': receiverPhone,
      'receiver_delivery_address_snapshot': receiverDeliveryAddress,
      'declared_size_code': declaredSize.name.toUpperCase(),
      'declared_size_name': declaredSizeName,
      'category_description': categoryDescription,
      'payment_mode': paymentMode.name.toUpperCase(),
      'quoted_price_amount': quotedPrice.kobo,
      'final_price_amount': finalPrice.kobo,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// DTO for the Confirm Parcel RPC result.
class ConfirmParcelResultDto {
  const ConfirmParcelResultDto({
    required this.success,
    required this.shipmentId,
    required this.deliveryCode,
    required this.status,
    required this.confirmedSizeCode,
    required this.confirmedSizeName,
    required this.finalPrice,
  });

  final bool success;
  final String shipmentId;
  final String deliveryCode;
  final ShipmentStatus status;
  final String confirmedSizeCode;
  final String confirmedSizeName;
  final Money finalPrice;

  factory ConfirmParcelResultDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'PARCEL_CONFIRMED';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.parcelConfirmed;

    final priceKobo = (json['final_price_amount'] as num?)?.toInt() ?? 0;

    return ConfirmParcelResultDto(
      success: json['success'] as bool? ?? false,
      shipmentId: json['shipment_id'] as String? ?? '',
      deliveryCode: json['delivery_code'] as String? ?? 'CRL-0000-0000',
      status: status,
      confirmedSizeCode: json['confirmed_size_code'] as String? ?? 'MEDIUM',
      confirmedSizeName:
          json['confirmed_size_name'] as String? ?? 'Medium Package',
      finalPrice: Money.fromKobo(priceKobo),
    );
  }
}
