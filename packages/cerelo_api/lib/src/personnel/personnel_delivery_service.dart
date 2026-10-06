import 'dart:convert';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing destination batch receipt, manifest parcel reconciliation,
/// final-mile delivery queue, receiver payment collection, delivery completion,
/// and the mandatory Sender completion call SOP.
class PersonnelDeliveryService {
  PersonnelDeliveryService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Records physical destination arrival of an intercity Batch using physical Batch QR or Batch Code identifier.
  Future<bool> receiveDestinationBatch({
    required String batchIdentifier,
    String? batchId,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'receive_destination_batch_verified',
        params: {
          'p_batch_identifier': batchIdentifier.trim(),
          if (batchId != null) 'p_batch_id': batchId,
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
        message: 'Failed to receive batch at destination: $e',
      );
    }
  }

  /// Reconciles an individual parcel in the destination Batch manifest (e.g. PRESENT, MISSING, DAMAGED).
  Future<bool> reconcileBatchParcel({
    required String batchId,
    required String parcelId,
    required String disposition,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'reconcile_batch_parcel',
        params: {
          'p_batch_id': batchId,
          'p_parcel_id': parcelId,
          'p_disposition': disposition.toUpperCase(),
          'p_notes': notes?.trim(),
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Completes Batch reconciliation once all expected parcels have been accounted for.
  Future<bool> completeBatchReconciliation(String batchId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'complete_batch_reconciliation',
        params: {'p_batch_id': batchId},
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
        message: 'Failed to complete reconciliation: $e',
      );
    }
  }

  /// Fetches the final-mile doorstep delivery work queue at the destination hub.
  Future<List<DeliveryTaskDto>> getReadyForDeliveryQueue() async {
    try {
      final response = await _client.rpc<dynamic>('get_ready_for_delivery_queue');
      if (response == null) return [];
      final dynamic rawList =
          response is String ? jsonDecode(response) : response;
      if (rawList is! List) return [];
      final list = rawList
          .map((json) =>
              DeliveryTaskDto.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      return list;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to load ready for delivery queue: $e',
      );
    }
  }

  /// Starts physical final-mile delivery ("Going for Delivery") and claims the delivery task.
  Future<bool> startFinalDelivery(String shipmentId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'start_final_delivery',
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
        message: 'Failed to start final delivery: $e',
      );
    }
  }

  /// Records physical payment (Cash or Transfer) collected from Receiver at delivery.
  Future<bool> recordReceiverPayment({
    required String shipmentId,
    required Money amount,
    String method = 'CASH',
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'record_physical_payment',
        params: {
          'p_shipment_id': shipmentId,
          'p_payer_party': 'RECEIVER',
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
        message: 'Failed to record receiver payment: $e',
      );
    }
  }

  /// Executes atomic Mark Delivered transaction upon physical handover to Receiver.
  Future<bool> markDelivered({
    required String shipmentId,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'mark_delivered',
        params: {
          'p_shipment_id': shipmentId,
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
        message: 'Failed to mark delivered: $e',
      );
    }
  }

  /// Records the mandatory Sender completion phone call outcome made from Receiver's doorstep.
  Future<bool> recordSenderCompletionCall({
    required String shipmentId,
    required String outcome,
    String? notes,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'record_sender_completion_call',
        params: {
          'p_shipment_id': shipmentId,
          'p_outcome': outcome.toUpperCase(),
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
