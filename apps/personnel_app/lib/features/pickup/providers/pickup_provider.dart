import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local/personnel_local_db.dart';

/// Provider for [PersonnelPickupService].
final personnelPickupServiceProvider = Provider<PersonnelPickupService>((ref) {
  return PersonnelPickupService();
});

/// Provider for the active Personnel pickup work queue.
///
/// LOCAL-FIRST: Caches the fetched pickup queue in SQLite.
/// If offline or network error occurs, seamlessly falls back to cached pickups.
final pickupQueueProvider =
    FutureProvider.autoDispose<List<PickupTaskDto>>((ref) async {
  final service = ref.watch(personnelPickupServiceProvider);
  final client = CereloSupabaseClient.instance;
  final currentUserId = client.auth.currentUser?.id;
  final localDb = PersonnelLocalDb.instance;

  if (currentUserId == null) return [];

  // 1. Instant SQLite read (frame 0)
  final cached = await localDb.loadPickups(currentUserId);
  final cachedList = cached.pickups.isNotEmpty
      ? cached.pickups.map((j) => PickupTaskDto.fromJson(j)).toList()
      : <PickupTaskDto>[];

  // 2. Fast network fetch with 3s timeout
  try {
    final liveQueue = await service.getPickupQueue().timeout(
      const Duration(seconds: 3),
    );
    await localDb.savePickups(
      userId: currentUserId,
      pickups: liveQueue.map((p) => p.toJson()).toList(),
    );
    return liveQueue;
  } catch (e) {
    // 3. If network fails or times out, return cached pickups immediately
    return cachedList;
  }
});

/// State of an active pickup workflow execution.
class ActivePickupState {
  const ActivePickupState({
    required this.task,
    this.isReceiverVerified = false,
    this.receiverVerificationOutcome,
    this.verifiedSize,
    this.isPaymentCollected = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.confirmedResult,
  });

  final PickupTaskDto task;
  final bool isReceiverVerified;
  final String? receiverVerificationOutcome;
  final ParcelSize? verifiedSize;
  final bool isPaymentCollected;
  final bool isSubmitting;
  final String? errorMessage;
  final ConfirmParcelResultDto? confirmedResult;

  bool get isClaimed =>
      task.isClaimedByMe || task.assignedPickupPersonnelId != null;

  ActivePickupState copyWith({
    PickupTaskDto? task,
    bool? isReceiverVerified,
    String? receiverVerificationOutcome,
    ParcelSize? verifiedSize,
    bool? isPaymentCollected,
    bool? isSubmitting,
    String? errorMessage,
    ConfirmParcelResultDto? confirmedResult,
  }) {
    return ActivePickupState(
      task: task ?? this.task,
      isReceiverVerified: isReceiverVerified ?? this.isReceiverVerified,
      receiverVerificationOutcome:
          receiverVerificationOutcome ?? this.receiverVerificationOutcome,
      verifiedSize: verifiedSize ?? this.verifiedSize,
      isPaymentCollected: isPaymentCollected ?? this.isPaymentCollected,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      confirmedResult: confirmedResult ?? this.confirmedResult,
    );
  }
}

/// State notifier managing an individual pickup task lifecycle.
class ActivePickupNotifier extends StateNotifier<ActivePickupState> {
  ActivePickupNotifier({
    required PickupTaskDto task,
    required this.service,
    required this.ref,
  }) : super(ActivePickupState(
          task: task,
          verifiedSize: task.declaredSize,
          isPaymentCollected: task.paymentMode == PaymentMode.receiverPays,
        ));

  final PersonnelPickupService service;
  final Ref ref;

  /// Explicitly accepts/claims the pickup task.
  Future<bool> acceptPickup() async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final success = await service.claimPickupTask(state.task.id);
      if (success) {
        state = state.copyWith(
          isSubmitting: false,
          task: PickupTaskDto(
            id: state.task.id,
            deliveryCode: state.task.deliveryCode,
            status: state.task.status,
            originCity: state.task.originCity,
            destinationCity: state.task.destinationCity,
            originHubId: state.task.originHubId,
            destinationHubId: state.task.destinationHubId,
            isClaimedByMe: true,
            isAvailable: false,
            senderName: state.task.senderName,
            senderPhone: state.task.senderPhone,
            senderPickupAddress: state.task.senderPickupAddress,
            landmark: state.task.landmark,
            deliveryInstructions: state.task.deliveryInstructions,
            receiverName: state.task.receiverName,
            receiverPhone: state.task.receiverPhone,
            receiverDeliveryAddress: state.task.receiverDeliveryAddress,
            declaredSize: state.task.declaredSize,
            declaredSizeName: state.task.declaredSizeName,
            categoryDescription: state.task.categoryDescription,
            paymentMode: state.task.paymentMode,
            quotedPrice: state.task.quotedPrice,
            finalPrice: state.task.finalPrice,
            createdAt: state.task.createdAt,
          ),
        );
        ref.invalidate(pickupQueueProvider);
        return true;
      }
      state = state.copyWith(isSubmitting: false, errorMessage: 'Failed to claim task.');
      return false;
    } catch (e) {
      final msg = e is CereloApiError ? e.message : 'Failed to claim task: $e';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> recordReceiverVerification({
    required String outcome,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final isVerified = await service.recordReceiverVerification(
        shipmentId: state.task.id,
        outcome: outcome,
        notes: notes,
      );
      state = state.copyWith(
        isSubmitting: false,
        isReceiverVerified: isVerified,
        receiverVerificationOutcome: outcome,
      );
      return isVerified;
    } catch (e) {
      final msg = e is CereloApiError ? e.message : 'Failed to record verification: $e';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> updateParcelSize(ParcelSize newSize, {String? reason}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updatedPrice = await service.verifyAndCorrectParcelSize(
        shipmentId: state.task.id,
        sizeTier: newSize,
        reason: reason,
      );
      state = state.copyWith(
        isSubmitting: false,
        verifiedSize: newSize,
        task: PickupTaskDto(
          id: state.task.id,
          deliveryCode: state.task.deliveryCode,
          status: state.task.status,
          originCity: state.task.originCity,
          destinationCity: state.task.destinationCity,
          originHubId: state.task.originHubId,
          destinationHubId: state.task.destinationHubId,
          isClaimedByMe: state.task.isClaimedByMe,
          isAvailable: state.task.isAvailable,
          senderName: state.task.senderName,
          senderPhone: state.task.senderPhone,
          senderPickupAddress: state.task.senderPickupAddress,
          landmark: state.task.landmark,
          deliveryInstructions: state.task.deliveryInstructions,
          receiverName: state.task.receiverName,
          receiverPhone: state.task.receiverPhone,
          receiverDeliveryAddress: state.task.receiverDeliveryAddress,
          declaredSize: state.task.declaredSize,
          declaredSizeName: state.task.declaredSizeName,
          categoryDescription: state.task.categoryDescription,
          paymentMode: state.task.paymentMode,
          quotedPrice: state.task.quotedPrice,
          finalPrice: updatedPrice,
          createdAt: state.task.createdAt,
        ),
      );
    } catch (e) {
      final msg = e is CereloApiError ? e.message : 'Failed to update size: $e';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
    }
  }

  /// Authoritatively adjusts the final agreed fare with the Sender after physical inspection.
  Future<bool> adjustFare({
    required Money newFare,
    required String reason,
    bool senderAgreed = true,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updatedPrice = await service.adjustPickupFare(
        shipmentId: state.task.id,
        finalFare: newFare,
        reason: reason,
        senderAgreed: senderAgreed,
      );
      state = state.copyWith(
        isSubmitting: false,
        task: state.task.copyWith(
          finalPrice: updatedPrice,
        ),
      );
      return true;
    } catch (e) {
      final msg = e is CereloApiError ? e.message : 'Failed to adjust fare: $e';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> recordSenderPayment({String method = 'CASH'}) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final amountToCollect = state.task.paymentMode == PaymentMode.splitPayment
          ? Money.fromKobo(state.task.finalPrice.kobo ~/ 2)
          : state.task.finalPrice;

      final success = await service.recordPhysicalPayment(
        shipmentId: state.task.id,
        payerParty: 'SENDER',
        amount: amountToCollect,
        method: 'CASH',
      );
      if (success) {
        state = state.copyWith(
          isSubmitting: false,
          isPaymentCollected: true,
        );
      }
      return success;
    } catch (e) {
      final msg = e is CereloApiError
          ? e.message
          : 'Internet connection required to confirm this action. Your work details are still available offline.';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> confirmParcel() async {
    if (state.verifiedSize == null) {
      state = state.copyWith(errorMessage: 'Please select a verified parcel size.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final result = await service.confirmParcelPickup(
        shipmentId: state.task.id,
        verifiedSize: state.verifiedSize!,
      );

      state = state.copyWith(
        isSubmitting: false,
        confirmedResult: result,
      );

      ref.invalidate(pickupQueueProvider);
      return true;
    } catch (e) {
      final msg = e is CereloApiError
          ? e.message
          : 'Internet connection required to confirm this action. Your work details are still available offline.';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> recordException({
    required String reason,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final success = await service.recordPickupException(
        shipmentId: state.task.id,
        reason: reason,
        notes: notes,
      );
      state = state.copyWith(isSubmitting: false);
      if (success) {
        ref.invalidate(pickupQueueProvider);
      }
      return success;
    } catch (e) {
      final msg = e is CereloApiError ? e.message : 'Failed to record exception: $e';
      state = state.copyWith(isSubmitting: false, errorMessage: msg);
      return false;
    }
  }
}

/// Provider family for active pickup execution state.
final activePickupProvider = StateNotifierProvider.family
    .autoDispose<ActivePickupNotifier, ActivePickupState, PickupTaskDto>(
  (ref, task) {
    final service = ref.watch(personnelPickupServiceProvider);
    return ActivePickupNotifier(task: task, service: service, ref: ref);
  },
);
