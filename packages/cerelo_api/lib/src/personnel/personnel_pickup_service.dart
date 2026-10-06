import 'dart:convert';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing Personnel field pickup operations, physical inspections,
/// receiver phone verification calls, cash collection, and atomic parcel confirmation.
class PersonnelPickupService {
  PersonnelPickupService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Fetches the active pickup work queue scoped to the Personnel's operating hub/city.
  Future<List<PickupTaskDto>> getPickupQueue() async {
    try {
      final response = await _client.rpc<dynamic>('get_personnel_pickup_queue');
      if (response == null) return [];
      final dynamic rawList =
          response is String ? jsonDecode(response) : response;
      if (rawList is! List) return [];
      final list = rawList
          .map((json) => PickupTaskDto.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      return list;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const CereloApiError(
          code: CereloErrorCode.forbidden,
          message: 'Personnel access required.',
        );
      }
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to load pickup tasks: ${e.message}',
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to load pickup tasks: $e',
      );
    }
  }

  /// Atomically claims/accepts a pickup task for the calling Personnel.
  Future<bool> claimPickupTask(String shipmentId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'claim_pickup_task',
        params: {'p_shipment_id': shipmentId},
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.conflict,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to claim pickup task: $e',
      );
    }
  }

  /// Starts or claims a pickup task.
  Future<bool> startPickup(String shipmentId) async {
    return claimPickupTask(shipmentId);
  }

  /// Records the mandatory receiver phone verification call outcome.
  Future<bool> recordReceiverVerification({
    required String shipmentId,
    required String outcome,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'record_receiver_verification',
        params: {
          'p_shipment_id': shipmentId,
          'p_outcome': outcome.trim(),
          'p_notes': notes?.trim(),
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true && map['is_verified'] == true;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to record verification: $e',
      );
    }
  }

  /// Physically verifies and corrects parcel size tier, recalculating price authoritatively.
  Future<Money> verifyAndCorrectParcelSize({
    required String shipmentId,
    required ParcelSize sizeTier,
    String? reason,
    bool senderAcknowledged = true,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'verify_and_correct_parcel_size',
        params: {
          'p_shipment_id': shipmentId,
          'p_size_tier_code': sizeTier.name.toUpperCase(),
          'p_reason': reason?.trim(),
          'p_sender_acknowledged': senderAcknowledged,
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      final finalKobo = (map['final_price_amount'] as num?)?.toInt() ?? 0;
      return Money.fromKobo(finalKobo);
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to adjust parcel size: $e',
      );
    }
  }

  /// Authoritatively adjusts the final agreed fare with the Sender after physical inspection.
  Future<Money> adjustPickupFare({
    required String shipmentId,
    required Money finalFare,
    required String reason,
    bool senderAgreed = true,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'adjust_pickup_fare',
        params: {
          'p_shipment_id': shipmentId,
          'p_final_price_amount': finalFare.kobo,
          'p_reason': reason.trim(),
          'p_sender_agreed': senderAgreed,
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      final finalKobo = (map['final_price_amount'] as num?)?.toInt() ?? finalFare.kobo;
      return Money.fromKobo(finalKobo);
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to adjust fare: $e',
      );
    }
  }

  /// Records physical payment (Cash or Bank Transfer) collected by Personnel.
  Future<bool> recordPhysicalPayment({
    required String shipmentId,
    required String payerParty,
    required Money amount,
    String method = 'CASH',
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'record_physical_payment',
        params: {
          'p_shipment_id': shipmentId,
          'p_payer_party': payerParty.toUpperCase(),
          'p_amount': amount.kobo,
          'p_method': method.toUpperCase(),
          'p_idempotency_key': idempotencyKey,
        },
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
        message: 'Failed to record payment: $e',
      );
    }
  }

  /// Executes atomic Confirm Parcel transaction, transferring physical custody to Cerelo
  /// and generating the authoritative Delivery Code.
  Future<ConfirmParcelResultDto> confirmParcelPickup({
    required String shipmentId,
    required ParcelSize verifiedSize,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'confirm_parcel_pickup',
        params: {
          'p_shipment_id': shipmentId,
          'p_verified_size_code': verifiedSize.name.toUpperCase(),
          'p_idempotency_key': idempotencyKey,
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return ConfirmParcelResultDto.fromJson(map);
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to confirm parcel: $e',
      );
    }
  }

  /// Records structured pickup exception when physical collection cannot proceed.
  Future<bool> recordPickupException({
    required String shipmentId,
    required String reason,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'record_pickup_exception',
        params: {
          'p_shipment_id': shipmentId,
          'p_reason': reason.toUpperCase(),
          'p_notes': notes?.trim(),
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
