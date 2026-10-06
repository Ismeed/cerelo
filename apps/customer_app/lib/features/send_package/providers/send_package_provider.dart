import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../shipments/providers/shipments_provider.dart';

/// Draft state for the multi-step "Send a Package" flow.
class SendPackageDraft {
  const SendPackageDraft({
    this.originCity = 'Kano',
    this.destinationCity = 'Katsina',
    this.senderPickupAddress = '',
    this.landmark = '',
    this.pickupInstructions = '',
    this.receiverName = '',
    this.receiverPhone = '',
    this.receiverDeliveryAddress = '',
    this.deliveryInstructions = '',
    this.categoryDescription = '',
    this.parcelSize = ParcelSize.medium,
    this.paymentMode = PaymentMode.senderPays,
    this.senderPaymentAmount,
    this.currentQuote,
    this.isLoadingQuote = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.createdShipment,
    this.idempotencyKey,
  });

  final String originCity;
  final String destinationCity;
  final String senderPickupAddress;
  final String landmark;
  final String pickupInstructions;

  final String receiverName;
  final String receiverPhone;
  final String receiverDeliveryAddress;
  final String deliveryInstructions;

  final String categoryDescription;
  final ParcelSize parcelSize;

  final PaymentMode paymentMode;
  final Money? senderPaymentAmount;

  final DeliveryQuoteDto? currentQuote;
  final bool isLoadingQuote;
  final bool isSubmitting;
  final String? errorMessage;
  final ShipmentDto? createdShipment;

  /// Opaque UUID used for server-side idempotency.
  ///
  /// Generated once when the draft is initialised. Preserved across retries
  /// so that network timeouts and duplicate taps cannot create more than one
  /// shipment.  A new key is generated only when `reset()` is called to start
  /// an entirely new shipment submission.
  final String? idempotencyKey;

  SendPackageDraft copyWith({
    String? originCity,
    String? destinationCity,
    String? senderPickupAddress,
    String? landmark,
    String? pickupInstructions,
    String? receiverName,
    String? receiverPhone,
    String? receiverDeliveryAddress,
    String? deliveryInstructions,
    String? categoryDescription,
    ParcelSize? parcelSize,
    PaymentMode? paymentMode,
    Money? senderPaymentAmount,
    DeliveryQuoteDto? currentQuote,
    bool? isLoadingQuote,
    bool? isSubmitting,
    String? errorMessage,
    ShipmentDto? createdShipment,
    String? idempotencyKey,
  }) {
    return SendPackageDraft(
      originCity: originCity ?? this.originCity,
      destinationCity: destinationCity ?? this.destinationCity,
      senderPickupAddress: senderPickupAddress ?? this.senderPickupAddress,
      landmark: landmark ?? this.landmark,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverDeliveryAddress: receiverDeliveryAddress ?? this.receiverDeliveryAddress,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      categoryDescription: categoryDescription ?? this.categoryDescription,
      parcelSize: parcelSize ?? this.parcelSize,
      paymentMode: paymentMode ?? this.paymentMode,
      senderPaymentAmount: senderPaymentAmount ?? this.senderPaymentAmount,
      currentQuote: currentQuote ?? this.currentQuote,
      isLoadingQuote: isLoadingQuote ?? this.isLoadingQuote,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      createdShipment: createdShipment ?? this.createdShipment,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// State notifier managing the Send a Package workflow.
class SendPackageNotifier extends StateNotifier<SendPackageDraft> {
  SendPackageNotifier({required this.shipmentService, required this.ref})
      : super(SendPackageDraft(idempotencyKey: const Uuid().v4())) {
    refreshQuote();
  }

  final ShipmentService shipmentService;
  final Ref ref;

  void setRoute({required String origin, required String destination}) {
    state = state.copyWith(originCity: origin, destinationCity: destination);
    refreshQuote();
  }

  void switchCorridorDirection() {
    final newOrigin = state.destinationCity;
    final newDest = state.originCity;
    state = state.copyWith(originCity: newOrigin, destinationCity: newDest);
    refreshQuote();
  }

  void setPickupDetails({
    required String address,
    String? landmark,
    String? instructions,
  }) {
    state = state.copyWith(
      senderPickupAddress: address,
      landmark: landmark ?? '',
      pickupInstructions: instructions ?? '',
    );
  }

  void setReceiverDetails({
    required String name,
    required String phone,
    required String address,
    String? instructions,
  }) {
    state = state.copyWith(
      receiverName: name,
      receiverPhone: phone,
      receiverDeliveryAddress: address,
      deliveryInstructions: instructions ?? '',
    );
  }

  void setParcelDetails({
    required String description,
    required ParcelSize size,
  }) {
    state = state.copyWith(
      categoryDescription: description,
      parcelSize: size,
    );
    refreshQuote();
  }

  void setPaymentDetails({
    required PaymentMode mode,
    Money? senderAmount,
  }) {
    state = state.copyWith(
      paymentMode: mode,
      senderPaymentAmount: senderAmount,
    );
  }

  Future<void> refreshQuote() async {
    state = state.copyWith(isLoadingQuote: true, errorMessage: null);
    try {
      final quote = await shipmentService.getDeliveryQuote(
        originCity: state.originCity,
        destinationCity: state.destinationCity,
        sizeTier: state.parcelSize,
      );
      state = state.copyWith(
        currentQuote: quote,
        isLoadingQuote: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingQuote: false,
        errorMessage: 'Could not fetch live delivery quote.',
      );
    }
  }

  /// Submits the shipment request to the server.
  ///
  /// Client-side protection:
  /// - Synchronously rejects duplicate in-flight calls via `isSubmitting` guard.
  /// - The `idempotencyKey` is preserved across retries so network timeouts or
  ///   accidental double-taps never create a second shipment.
  ///
  /// Server-side protection:
  /// - The `p_idempotency_key` parameter is enforced UNIQUE in the database.
  ///   Concurrent identical submissions from the same customer return the
  ///   original record.
  Future<ShipmentDto?> submitShipmentRequest() async {
    // Synchronous guard — reject duplicate taps / concurrent calls immediately.
    if (state.isSubmitting) return null;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    // Ensure we always have an idempotency key.
    final idempotencyKey = state.idempotencyKey ?? const Uuid().v4();
    if (state.idempotencyKey == null) {
      state = state.copyWith(idempotencyKey: idempotencyKey);
    }

    try {
      final input = CreateShipmentRequestInput(
        originCity: state.originCity,
        destinationCity: state.destinationCity,
        senderPickupAddress: state.senderPickupAddress,
        receiverName: state.receiverName,
        receiverPhone: state.receiverPhone,
        receiverDeliveryAddress: state.receiverDeliveryAddress,
        parcelSize: state.parcelSize,
        categoryDescription: state.categoryDescription.isNotEmpty
            ? state.categoryDescription
            : 'General Package',
        paymentMode: state.paymentMode,
        senderPaymentAmount: state.paymentMode == PaymentMode.splitPayment
            ? state.senderPaymentAmount
            : null,
        deliveryInstructions: state.deliveryInstructions.isNotEmpty
            ? state.deliveryInstructions
            : null,
        landmark: state.landmark.isNotEmpty ? state.landmark : null,
        idempotencyKey: idempotencyKey,
      );

      final shipment = await shipmentService.createShipmentRequest(input);

      // Invalidate queries so Home and Shipments list update immediately
      ref.invalidate(customerActiveShipmentsProvider);
      ref.invalidate(customerRecentShipmentsProvider);
      ref.invalidate(customerShipmentsProvider);

      state = state.copyWith(
        isSubmitting: false,
        createdShipment: shipment,
      );

      return shipment;
    } catch (e) {
      final message = e is CereloApiError ? e.message : 'Failed to submit request: $e';
      // Preserve idempotencyKey on error so the SAME key is used on retry.
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: message,
      );
      return null;
    }
  }

  /// Resets the draft for a brand-new shipment.
  ///
  /// Generates a fresh `idempotencyKey` so the next submission is independent.
  void reset() {
    state = SendPackageDraft(idempotencyKey: const Uuid().v4());
    refreshQuote();
  }
}

final sendPackageProvider =
    StateNotifierProvider.autoDispose<SendPackageNotifier, SendPackageDraft>(
  (ref) {
    final service = ref.watch(shipmentServiceProvider);
    return SendPackageNotifier(shipmentService: service, ref: ref);
  },
);
