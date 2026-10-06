import 'package:cerelo_core/cerelo_core.dart';

/// Data Transfer Object for a Customer's Shipment.
///
/// Represents the sanitized, customer-facing view of a shipment.
/// Enforces data minimization:
/// - Never exposes internal Batch IDs, Vehicle plates, or Personnel identities.
/// - Never exposes internal operational incident logs.
/// - Formats counterpart name and relationship safely based on viewer's role.
class ShipmentDto {
  const ShipmentDto({
    required this.id,
    this.deliveryCode,
    required this.status,
    required this.originCity,
    required this.destinationCity,
    required this.senderCustomerId,
    this.receiverCustomerId,
    required this.senderNameSnapshot,
    required this.senderPhoneSnapshot,
    required this.senderPickupAddressSnapshot,
    required this.receiverNameSnapshot,
    required this.receiverPhoneSnapshot,
    required this.receiverDeliveryAddressSnapshot,
    this.declaredSize = ParcelSize.medium,
    this.confirmedSize,
    this.categoryDescription = 'General Goods',
    required this.paymentMode,
    required this.quotedPrice,
    required this.finalPrice,
    this.senderPaymentStatus = PaymentStatus.pending,
    this.receiverPaymentStatus = PaymentStatus.notRequired,
    required this.createdAt,
    this.deliveredAt,
    this.receiverConfirmedAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  final String id;
  final String? deliveryCode;
  final ShipmentStatus status;
  final String originCity;
  final String destinationCity;

  // Cancellation metadata
  final DateTime? cancelledAt;
  final String? cancellationReason;

  /// Whether the customer can cancel before Personnel has confirmed the parcel.
  bool get canCancelRequest => status == ShipmentStatus.requested;

  /// Whether the customer can cancel after Personnel confirmation but before corridor transit.
  bool get canCancelDelivery =>
      status == ShipmentStatus.parcelConfirmed ||
      status == ShipmentStatus.atOriginHub;

  /// Whether this shipment has been cancelled.
  bool get isCancelled => status == ShipmentStatus.cancelled;

  // Participant IDs
  final String senderCustomerId;
  final String? receiverCustomerId;

  // Snapshots (immutable historical agreement)
  final String senderNameSnapshot;
  final String senderPhoneSnapshot;
  final String senderPickupAddressSnapshot;
  final String receiverNameSnapshot;
  final String receiverPhoneSnapshot;
  final String receiverDeliveryAddressSnapshot;

  // Parcel details
  final ParcelSize declaredSize;
  final ParcelSize? confirmedSize;
  final String categoryDescription;

  // Payment
  final PaymentMode paymentMode;
  final Money quotedPrice;
  final Money finalPrice;
  final PaymentStatus senderPaymentStatus;
  final PaymentStatus receiverPaymentStatus;

  // Timestamps
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? receiverConfirmedAt;

  /// Whether the current customer is the Sender of this shipment.
  bool isSender(String? currentUserId) =>
      currentUserId != null && senderCustomerId == currentUserId;

  /// Whether the current customer is the Receiver of this shipment.
  bool isReceiver(String? currentUserId) =>
      currentUserId != null && (receiverCustomerId == currentUserId || senderCustomerId != currentUserId);

  /// Returns the counterpart customer name relative to the current viewer.
  String counterpartName(String? currentUserId) {
    if (isSender(currentUserId)) {
      return receiverNameSnapshot.isNotEmpty ? receiverNameSnapshot : 'Receiver';
    } else {
      return senderNameSnapshot.isNotEmpty ? senderNameSnapshot : 'Sender';
    }
  }

  /// Returns formatted counterpart label (e.g. "To: Aliyu Bello" or "From: Kwari Store").
  String counterpartLabel(String? currentUserId) {
    if (isSender(currentUserId)) {
      final name = receiverNameSnapshot.isNotEmpty ? receiverNameSnapshot : 'Receiver';
      return 'To: $name';
    } else {
      final name = senderNameSnapshot.isNotEmpty ? senderNameSnapshot : 'Sender';
      return 'From: $name';
    }
  }

  /// Relationship badge label (SENT or RECEIVED).
  String relationshipBadge(String? currentUserId) =>
      isSender(currentUserId) ? 'SENT' : 'RECEIVED';

  /// Formatted route string (e.g. "Kano → Katsina").
  String get routeDisplay => '$originCity → $destinationCity';

  /// Formatted short date string (e.g. "Aug 17, 2026").
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[createdAt.month - 1];
    return '$month ${createdAt.day}, ${createdAt.year}';
  }

  factory ShipmentDto.fromJson(Map<String, dynamic> json) {
    final statusStr = json['current_status'] as String? ?? 'REQUESTED';
    final status = ShipmentStatus.fromString(statusStr.toLowerCase()) ??
        ShipmentStatus.requested;

    final paymentModeStr = json['payment_mode'] as String? ?? 'SENDER_PAYS';
    final paymentMode = PaymentMode.fromString(paymentModeStr.toLowerCase()) ??
        PaymentMode.senderPays;

    final declaredSizeStr = json['declared_size'] as String? ?? 'MEDIUM';
    final declaredSize = ParcelSize.fromString(declaredSizeStr.toLowerCase()) ??
        ParcelSize.medium;

    final confirmedSizeStr = json['confirmed_size'] as String?;
    final confirmedSize = confirmedSizeStr != null
        ? ParcelSize.fromString(confirmedSizeStr.toLowerCase())
        : null;

    final senderPayStatusStr = json['sender_payment_status'] as String? ?? 'PENDING';
    final senderPaymentStatus = PaymentStatus.fromString(senderPayStatusStr.toLowerCase()) ??
        PaymentStatus.pending;

    final receiverPayStatusStr = json['receiver_payment_status'] as String? ?? 'NOT_REQUIRED';
    final receiverPaymentStatus = PaymentStatus.fromString(receiverPayStatusStr.toLowerCase()) ??
        PaymentStatus.notRequired;

    final quotedKobo = (json['quoted_price_amount'] as num?)?.toInt() ?? 0;
    final finalKobo = (json['final_price_amount'] as num?)?.toInt() ?? quotedKobo;

    return ShipmentDto(
      id: json['id'] as String,
      deliveryCode: json['delivery_code'] as String?,  // null until confirm_parcel_pickup
      status: status,
      originCity: json['origin_city'] as String? ?? 'Kano',
      destinationCity: json['destination_city'] as String? ?? 'Katsina',
      senderCustomerId: json['sender_customer_id'] as String? ?? '',
      receiverCustomerId: json['receiver_customer_id'] as String?,
      senderNameSnapshot: json['sender_name_snapshot'] as String? ?? '',
      senderPhoneSnapshot: json['sender_phone_snapshot'] as String? ?? '',
      senderPickupAddressSnapshot:
          json['sender_pickup_address_snapshot'] as String? ?? '',
      receiverNameSnapshot: json['receiver_name_snapshot'] as String? ?? '',
      receiverPhoneSnapshot: json['receiver_phone_snapshot'] as String? ?? '',
      receiverDeliveryAddressSnapshot:
          json['receiver_delivery_address_snapshot'] as String? ?? '',
      declaredSize: declaredSize,
      confirmedSize: confirmedSize,
      categoryDescription:
          json['category_description'] as String? ?? 'General Package',
      paymentMode: paymentMode,
      quotedPrice: Money.fromKobo(quotedKobo),
      finalPrice: Money.fromKobo(finalKobo),
      senderPaymentStatus: senderPaymentStatus,
      receiverPaymentStatus: receiverPaymentStatus,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      receiverConfirmedAt: json['receiver_confirmed_at'] != null
          ? DateTime.parse(json['receiver_confirmed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_code': deliveryCode,  // null until confirm_parcel_pickup
      'current_status': status.name.toUpperCase(),
      'origin_city': originCity,
      'destination_city': destinationCity,
      'sender_customer_id': senderCustomerId,
      'receiver_customer_id': receiverCustomerId,
      'sender_name_snapshot': senderNameSnapshot,
      'sender_phone_snapshot': senderPhoneSnapshot,
      'sender_pickup_address_snapshot': senderPickupAddressSnapshot,
      'receiver_name_snapshot': receiverNameSnapshot,
      'receiver_phone_snapshot': receiverPhoneSnapshot,
      'receiver_delivery_address_snapshot': receiverDeliveryAddressSnapshot,
      'declared_size': declaredSize.name.toUpperCase(),
      'confirmed_size': confirmedSize?.name.toUpperCase(),
      'category_description': categoryDescription,
      'payment_mode': paymentMode.name.toUpperCase(),
      'quoted_price_amount': quotedPrice.kobo,
      'final_price_amount': finalPrice.kobo,
      'sender_payment_status': senderPaymentStatus.name.toUpperCase(),
      'receiver_payment_status': receiverPaymentStatus.name.toUpperCase(),
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'receiver_confirmed_at': receiverConfirmedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
    };
  }
}

/// DTO for a milestone event in a customer's shipment timeline.
class ShipmentTimelineEventDto {
  const ShipmentTimelineEventDto({
    required this.status,
    required this.title,
    required this.description,
    this.timestamp,
    required this.isCompleted,
    required this.isCurrent,
  });

  final ShipmentStatus status;
  final String title;
  final String description;
  final DateTime? timestamp;
  final bool isCompleted;
  final bool isCurrent;
}
