import 'dart:convert';
import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing Batch creation, membership validation, manifest confirmation,
/// transport association, and atomic middle-mile onboarding.
class PersonnelBatchService {
  PersonnelBatchService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Creates a new Draft Batch along the specified origin and destination hub corridor.
  Future<BatchSummaryDto> createBatch({
    required String originHubId,
    required String destinationHubId,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'create_batch',
        params: {
          'p_origin_hub_id': originHubId,
          'p_destination_hub_id': destinationHubId,
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return BatchSummaryDto(
        id: map['batch_id'] as String,
        batchReference: map['batch_reference'] as String,
        status: BatchStatus.draft,
        corridorCode: map['corridor_code'] as String? ?? 'KAN-KAT',
        originCity: 'Kano',
        destinationCity: 'Katsina',
        manifestParcelCount: 0,
        createdAt: DateTime.now(),
      );
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to create batch: $e',
      );
    }
  }

  /// Adds an eligible parcel to a Draft Batch.
  Future<bool> addParcelToBatch({
    required String batchId,
    required String parcelId,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'add_parcel_to_batch',
        params: {
          'p_batch_id': batchId,
          'p_parcel_id': parcelId,
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
        message: 'Failed to add parcel to batch: $e',
      );
    }
  }

  /// Removes a parcel from a Draft Batch before confirmation.
  Future<bool> removeParcelFromDraftBatch({
    required String batchId,
    required String parcelId,
    String? reason,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'remove_parcel_from_draft_batch',
        params: {
          'p_batch_id': batchId,
          'p_parcel_id': parcelId,
          'p_reason': reason ?? 'Removed before confirmation',
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Confirms a Batch manifest, freezing contents and generating the Batch QR token.
  Future<String> confirmBatch(String batchId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'confirm_batch',
        params: {'p_batch_id': batchId},
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['batch_qr_token'] as String? ?? '';
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to confirm batch: $e',
      );
    }
  }

  /// Associates the Batch with a middle-mile commercial transport provider and agreed cost.
  Future<bool> setBatchTransport({
    required String batchId,
    required String providerName,
    String? driverName,
    String? driverPhone,
    String? vehiclePlate,
    required Money agreedCost,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'set_batch_transport_arrangement',
        params: {
          'p_batch_id': batchId,
          'p_provider_name': providerName.trim(),
          'p_driver_name': driverName?.trim(),
          'p_driver_phone': driverPhone?.trim(),
          'p_vehicle_plate': vehiclePlate?.trim(),
          'p_agreed_cost_amount': agreedCost.kobo,
        },
      );
      final map = Map<String, dynamic>.from(response as Map);
      return map['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Atomically onboards the Batch upon physical vehicle departure,
  /// updating Batch, Parcels, and Shipments to IN_TRANSIT.
  Future<bool> onboardBatch(String batchId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'onboard_batch',
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
        message: 'Failed to onboard batch: $e',
      );
    }
  }

  /// Fetches the list of Batches filtered optionally by lifecycle state.
  Future<List<BatchSummaryDto>> getBatches({BatchStatus? status}) async {
    try {
      final response = await _client.rpc<dynamic>(
        'get_personnel_batches',
        params: {
          if (status != null) 'p_status': status.name.toUpperCase(),
        },
      );
      if (response == null) return [];
      final dynamic rawList =
          response is String ? jsonDecode(response) : response;
      if (rawList is! List) return [];
      final list = rawList
          .map((json) =>
              BatchSummaryDto.fromJson(Map<String, dynamic>.from(json as Map)))
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
        message: 'Failed to fetch batches: $e',
      );
    }
  }

  /// Fetches the full manifest for a specific Batch.
  Future<BatchManifestDto?> getBatchManifest(String batchId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'get_batch_manifest',
        params: {'p_batch_id': batchId},
      );
      final map = Map<String, dynamic>.from(response as Map);
      return BatchManifestDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Deletes an empty Draft Batch originating from the personnel's home hub.
  Future<bool> deleteDraftBatch(String batchId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'delete_draft_batch',
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
        message: 'Failed to delete draft batch: $e',
      );
    }
  }

  /// Cancels a Draft Batch that contains parcels, releasing all parcels back to origin hub staged pool.
  Future<bool> cancelDraftBatch({
    required String batchId,
    String? reason,
  }) async {
    try {
      final response = await _client.rpc<dynamic>(
        'cancel_draft_batch',
        params: {
          'p_batch_id': batchId,
          if (reason != null) 'p_reason': reason,
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
        message: 'Failed to cancel draft batch: $e',
      );
    }
  }

  /// Resolves an Inbound Batch for physical receipt using physical Batch QR token or Batch Code.
  Future<Map<String, dynamic>?> resolveInboundBatchForReceipt(String identifier) async {
    try {
      final response = await _client.rpc<dynamic>(
        'resolve_inbound_batch_for_receipt',
        params: {'p_batch_identifier': identifier.trim()},
      );
      final map = Map<String, dynamic>.from(response as Map);
      if (map['is_valid'] == false) return null;
      return map;
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      return null;
    }
  }

  /// Resolves a Batch by its Batch QR token or Batch Reference.
  Future<BatchSummaryDto?> resolveBatchByQrOrRef(String tokenOrRef) async {
    try {
      final response = await _client.rpc<dynamic>(
        'resolve_batch_by_qr_or_ref',
        params: {'p_token_or_ref': tokenOrRef.trim()},
      );
      final map = Map<String, dynamic>.from(response as Map);
      if (map['is_valid'] == false) return null;
      return BatchSummaryDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
