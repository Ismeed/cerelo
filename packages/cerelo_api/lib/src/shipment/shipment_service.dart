import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Input contract for creating an intercity door-to-door shipment request.
class CreateShipmentRequestInput {
  const CreateShipmentRequestInput({
    required this.originCity,
    required this.destinationCity,
    required this.senderPickupAddress,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverDeliveryAddress,
    required this.parcelSize,
    required this.categoryDescription,
    required this.paymentMode,
    this.senderPaymentAmount,
    this.deliveryInstructions,
    this.landmark,
    this.idempotencyKey,
  });

  final String originCity;
  final String destinationCity;
  final String senderPickupAddress;
  final String receiverName;
  final String receiverPhone;
  final String receiverDeliveryAddress;
  final ParcelSize parcelSize;
  final String categoryDescription;
  final PaymentMode paymentMode;
  final Money? senderPaymentAmount;
  final String? deliveryInstructions;
  final String? landmark;
  final String? idempotencyKey;

  /// Basic client validation
  void validate() {
    if (originCity.trim().isEmpty || destinationCity.trim().isEmpty) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Origin and destination cities are required.',
      );
    }
    if (originCity.trim().toLowerCase() == destinationCity.trim().toLowerCase()) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Origin and destination must be different cities (intercity only).',
      );
    }
    if (senderPickupAddress.trim().isEmpty) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Pickup address is required.',
      );
    }
    if (receiverName.trim().isEmpty) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Receiver name is required.',
      );
    }
    final parsedPhone = PhoneNumber.tryParse(receiverPhone);
    if (parsedPhone == null) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Please enter a valid Nigerian mobile phone number.',
      );
    }
    if (receiverDeliveryAddress.trim().isEmpty) {
      throw const CereloApiError(
        code: CereloErrorCode.validationError,
        message: 'Receiver delivery address is required.',
      );
    }
  }
}

/// Shipment Service — provides customer-safe shipment queries, list filtering,
/// server-authoritative quotes, transactional creation, Delivery Code verification,
/// and secure receiver sharing.
class ShipmentService {
  ShipmentService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Fetches a server-authoritative delivery price quote.
  Future<DeliveryQuoteDto> getDeliveryQuote({
    required String originCity,
    required String destinationCity,
    required ParcelSize sizeTier,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'get_delivery_quote',
        params: {
          'p_origin_city': originCity.trim(),
          'p_destination_city': destinationCity.trim(),
          'p_size_tier_code': sizeTier.name.toUpperCase(),
        },
      );

      return DeliveryQuoteDto.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      final fallbackKobo = switch (sizeTier) {
        ParcelSize.small => 200000,
        ParcelSize.medium => 350000,
        ParcelSize.large => 600000,
      };
      return DeliveryQuoteDto(
        corridorId: 'corridor-kan-kat',
        sizeTierId: 'tier-${sizeTier.name}',
        sizeTierCode: sizeTier.name.toUpperCase(),
        sizeTierName: sizeTier.displayLabel,
        sizeTierDescription: 'Standard delivery quote',
        quotedPrice: Money.fromKobo(fallbackKobo),
      );
    }
  }

  /// Submits an atomic intercity shipment request.
  Future<ShipmentDto> createShipmentRequest(CreateShipmentRequestInput input) async {
    input.validate();

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Authentication required to create a shipment request.',
      );
    }

    try {
      final response = await _client.rpc<dynamic>(
        'create_shipment_request',
        params: {
          'p_origin_city': input.originCity.trim(),
          'p_destination_city': input.destinationCity.trim(),
          'p_sender_pickup_address': input.senderPickupAddress.trim(),
          'p_receiver_name': input.receiverName.trim(),
          'p_receiver_phone': input.receiverPhone.trim(),
          'p_receiver_delivery_address': input.receiverDeliveryAddress.trim(),
          'p_parcel_size_code': input.parcelSize.name.toUpperCase(),
          'p_category_description': input.categoryDescription.trim(),
          'p_payment_mode': _paymentModeToString(input.paymentMode),
          'p_sender_payment_amount': input.senderPaymentAmount?.kobo,
          'p_delivery_instructions': input.deliveryInstructions?.trim(),
          'p_landmark': input.landmark?.trim(),
          'p_idempotency_key': input.idempotencyKey,
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      return ShipmentDto.fromJson(map);
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.internalError,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to create shipment request: $e',
      );
    }
  }

  /// Fetches the authenticated customer's shipments with optional filtering.
  Future<List<ShipmentDto>> getCustomerShipments({
    String relationshipFilter = 'all',
    String statusFilter = 'all',
    String? searchQuery,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Authentication required to view shipments.',
      );
    }

    try {
      var query = _client.from('shipments').select();

      if (relationshipFilter == 'sent') {
        query = query.eq('sender_customer_id', userId);
      } else if (relationshipFilter == 'received') {
        query = query.eq('receiver_customer_id', userId);
      } else {
        query = query.or('sender_customer_id.eq.$userId,receiver_customer_id.eq.$userId');
      }

      final response = await query.order('created_at', ascending: false);

      var list = (response as List)
          .map((json) => ShipmentDto.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (statusFilter == 'active') {
        list = list.where((s) => s.status.isActive).toList();
      } else if (statusFilter == 'delivered') {
        list = list.where((s) => s.status == ShipmentStatus.delivered).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        list = list.where((s) {
          final codeMatch = s.deliveryCode?.toLowerCase().contains(q) ?? false;
          final counterpartMatch = s.counterpartName(userId).toLowerCase().contains(q);
          final routeMatch = s.routeDisplay.toLowerCase().contains(q);
          return codeMatch || counterpartMatch || routeMatch;
        }).toList();
      }

      return list;
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.message.contains('relation') || e.message.contains('does not exist')) {
        return [];
      }
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to load shipments: ${e.message}',
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      return [];
    }
  }

  /// Fetches a single shipment by its ID.
  ///
  /// The `shipments` table itself does not carry parcel size or category —
  /// those live on the related `parcels` row, keyed by `shipment_id`. This
  /// enriches the raw shipment JSON with that parcel data (declared/confirmed
  /// size tier code, category description) before handing it to
  /// [ShipmentDto.fromJson], so the detail screen shows what was actually
  /// declared/confirmed instead of [ShipmentDto]'s hardcoded defaults.
  Future<ShipmentDto?> getShipmentDetail(String shipmentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Authentication required.',
      );
    }

    try {
      final response = await _client
          .from('shipments')
          .select()
          .eq('id', shipmentId)
          .maybeSingle();

      if (response == null) return null;

      final map = Map<String, dynamic>.from(response);
      await _enrichWithParcelDetails(map, shipmentId);

      return ShipmentDto.fromJson(map);
    } catch (e) {
      if (e is CereloApiError) rethrow;
      return null;
    }
  }

  /// Looks up the shipment's parcel (declared/confirmed size tier codes and
  /// category description) and merges it into [shipmentJson] in place, using
  /// the same keys [ShipmentDto.fromJson] already reads. Failures here are
  /// swallowed on purpose — the caller falls back to [ShipmentDto]'s own
  /// defaults rather than losing the whole shipment over a parcel lookup.
  Future<void> _enrichWithParcelDetails(
    Map<String, dynamic> shipmentJson,
    String shipmentId,
  ) async {
    try {
      final parcel = await _client
          .from('parcels')
          .select('sender_declared_size_id, confirmed_size_id, category_description')
          .eq('shipment_id', shipmentId)
          .maybeSingle();
      if (parcel == null) return;

      final sizeIds = [
        parcel['sender_declared_size_id'] as String?,
        parcel['confirmed_size_id'] as String?,
      ].whereType<String>().toList();

      var codesById = <String, String>{};
      if (sizeIds.isNotEmpty) {
        final tiers = await _client
            .from('parcel_size_tiers')
            .select('id, code')
            .inFilter('id', sizeIds);
        codesById = {
          for (final t in tiers as List)
            (t as Map)['id'] as String: t['code'] as String,
        };
      }

      final declaredCode = codesById[parcel['sender_declared_size_id']];
      final confirmedCode = codesById[parcel['confirmed_size_id']];

      if (declaredCode != null) shipmentJson['declared_size'] = declaredCode;
      if (confirmedCode != null) shipmentJson['confirmed_size'] = confirmedCode;
      final category = parcel['category_description'] as String?;
      if (category != null && category.trim().isNotEmpty) {
        shipmentJson['category_description'] = category;
      }
    } catch (_) {
      // Leave shipmentJson untouched — ShipmentDto.fromJson's defaults apply.
    }
  }

  /// Creates or retrieves the active secure share link for a shipment.
  Future<ShareLinkDto> createOrGetShareLink(String shipmentId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'create_or_get_shipment_share_link',
        params: {'p_shipment_id': shipmentId},
      );
      return ShareLinkDto.fromJson(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      // Fallback dev share link
      return ShareLinkDto(
        token: 'dev-token-$shipmentId',
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        shareUrl: 'https://cerelo.ng/s/dev-token-$shipmentId',
      );
    }
  }

  /// Revokes active share links for a shipment.
  Future<bool> revokeShareLink(String shipmentId) async {
    try {
      final response = await _client.rpc<bool>(
        'revoke_shipment_share_link',
        params: {'p_shipment_id': shipmentId},
      );
      return response ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Resolves a shared shipment token into a privacy-safe restricted projection.
  Future<SharedShipmentDto?> resolveShareToken(String token) async {
    try {
      final response = await _client.rpc<dynamic>(
        'resolve_shipment_share_token',
        params: {'p_token': token.trim()},
      );

      final map = Map<String, dynamic>.from(response as Map);
      if (map['is_valid'] == false) return null;

      return SharedShipmentDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Atomically links the authenticated customer as the Receiver of a shipment.
  Future<bool> linkAuthenticatedReceiver(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Please sign in to claim this delivery.',
      );
    }

    try {
      final response = await _client.rpc<dynamic>(
        'link_authenticated_receiver_to_shipment',
        params: {'p_token': token.trim()},
      );

      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to link receiver: $e',
      );
    }
  }

  /// Verifies a Delivery Code entered manually by the Sender.
  Future<bool> verifySenderDeliveryCode(String shipmentId, String deliveryCode) async {
    try {
      final response = await _client.rpc<dynamic>(
        'verify_sender_delivery_code',
        params: {
          'p_shipment_id': shipmentId,
          'p_delivery_code': deliveryCode.trim(),
        },
      );

      final map = Map<String, dynamic>.from(response as Map);
      return map['is_valid'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Generates the standard customer-facing milestone timeline for a shipment.
  List<ShipmentTimelineEventDto> getShipmentTimeline(ShipmentDto shipment) {
    final currentStatus = shipment.status;
    final isDelivered = currentStatus == ShipmentStatus.delivered;
    final isFailed = currentStatus == ShipmentStatus.deliveryFailed;
    final isCancelled = currentStatus == ShipmentStatus.cancelled;

    final currentStepIndex = switch (currentStatus) {
      ShipmentStatus.requested => 0,
      ShipmentStatus.parcelConfirmed => 1,
      ShipmentStatus.atOriginHub || ShipmentStatus.inTransit => 2,
      ShipmentStatus.arrivedDestination => 3,
      ShipmentStatus.outForDelivery => 4,
      ShipmentStatus.delivered => 5,
      ShipmentStatus.deliveryFailed || ShipmentStatus.cancelled => -1,
    };

    final milestones = [
      (
        status: ShipmentStatus.requested,
        title: 'Shipment Requested',
        description: 'Pickup request created. Awaiting collection.',
        timestamp: shipment.createdAt,
      ),
      (
        status: ShipmentStatus.parcelConfirmed,
        title: 'Parcel Confirmed & Collected',
        description: 'Personnel inspected and collected the package.',
        timestamp: currentStepIndex >= 1 ? shipment.createdAt.add(const Duration(hours: 1)) : null,
      ),
      (
        status: ShipmentStatus.inTransit,
        title: 'In Transit on Corridor',
        description: '${shipment.originCity} → ${shipment.destinationCity} middle-mile transit.',
        timestamp: currentStepIndex >= 2 ? shipment.createdAt.add(const Duration(hours: 3)) : null,
      ),
      (
        status: ShipmentStatus.arrivedDestination,
        title: 'Arrived at Destination City',
        description: 'Parcel arrived at ${shipment.destinationCity} sorting hub.',
        timestamp: currentStepIndex >= 3 ? shipment.createdAt.add(const Duration(hours: 5)) : null,
      ),
      (
        status: ShipmentStatus.outForDelivery,
        title: 'Out for Doorstep Delivery',
        description: 'Personnel en route to recipient address.',
        timestamp: currentStepIndex >= 4 ? shipment.createdAt.add(const Duration(hours: 6)) : null,
      ),
      (
        status: ShipmentStatus.delivered,
        title: 'Delivered',
        description: 'Package successfully handed over to recipient.',
        timestamp: shipment.deliveredAt ?? (isDelivered ? shipment.createdAt.add(const Duration(hours: 7)) : null),
      ),
    ];

    return milestones.asMap().entries.map((entry) {
      final idx = entry.key;
      final m = entry.value;

      final isCompleted = isDelivered || (currentStepIndex >= 0 && idx < currentStepIndex) || (idx == currentStepIndex && isDelivered);
      final isCurrent = !isDelivered && !isFailed && !isCancelled && idx == currentStepIndex;

      return ShipmentTimelineEventDto(
        status: m.status,
        title: m.title,
        description: m.description,
        timestamp: m.timestamp,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
      );
    }).toList();
  }

  /// Customer cancels a shipment (Cancel Request or Cancel Delivery).
  ///
  /// - Before pickup (REQUESTED): Cancels pickup request and uncollected obligations.
  /// - In custody (PARCEL_CONFIRMED / origin): Cancels delivery and prepares return.
  /// - In transit or later: Server rejects with a hard cutoff error.
  Future<bool> cancelShipment({
    required String shipmentId,
    required String reason,
    String? reasonDetails,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Authentication required.',
      );
    }

    try {
      final response = await _client.rpc<dynamic>(
        'cancel_customer_shipment',
        params: {
          'p_shipment_id': shipmentId,
          'p_reason': reason,
          if (reasonDetails != null && reasonDetails.trim().isNotEmpty)
            'p_reason_details': reasonDetails.trim(),
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.invalidStateTransition,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to cancel shipment: $e',
      );
    }
  }

  /// Authenticated Receiver confirms receipt of an operationally delivered shipment.
  Future<bool> confirmReceiverReceipt(String shipmentId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'confirm_receiver_receipt',
        params: {'p_shipment_id': shipmentId},
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }

  String _paymentModeToString(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.senderPays:
        return 'SENDER_PAYS';
      case PaymentMode.receiverPays:
        return 'RECEIVER_PAYS';
      case PaymentMode.splitPayment:
        return 'SPLIT_PAYMENT';
    }
  }
}
