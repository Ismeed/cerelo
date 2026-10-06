import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service managing origin-hub parcel operations: QR identity generation,
/// scanner resolution, Delivery Code fallback, hub physical receipt, and Ready for Batch read models.
class PersonnelHubService {
  PersonnelHubService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Ensures that a confirmed parcel has an active Parcel QR token.
  Future<String> ensureParcelQr(String parcelId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'ensure_parcel_qr',
        params: {'p_parcel_id': parcelId},
      );
      return response.toString();
    } on PostgrestException catch (e) {
      throw CereloApiError(
        code: CereloErrorCode.fromCode(e.code) ?? CereloErrorCode.forbidden,
        message: e.message,
      );
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to generate parcel QR: $e',
      );
    }
  }

  /// Resolves an operational parcel via scanned QR token.
  Future<ResolvedParcelDto?> resolveParcelByQr(String qrToken) async {
    try {
      final response = await _client.rpc<dynamic>(
        'resolve_parcel_by_qr',
        params: {'p_qr_token': qrToken.trim()},
      );
      final map = Map<String, dynamic>.from(response as Map);
      if (map['is_valid'] == false) return null;

      return ResolvedParcelDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Resolves an operational parcel via manual Delivery Code fallback.
  Future<ResolvedParcelDto?> resolveParcelByDeliveryCode(String deliveryCode) async {
    try {
      final response = await _client.rpc<dynamic>(
        'resolve_parcel_by_delivery_code',
        params: {'p_delivery_code': deliveryCode.trim()},
      );
      final map = Map<String, dynamic>.from(response as Map);
      if (map['is_valid'] == false) return null;

      return ResolvedParcelDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Atomically confirms physical receipt of a parcel at the origin Cerelo hub/point.
  Future<bool> receiveParcelAtOriginHub(String parcelId) async {
    try {
      final response = await _client.rpc<dynamic>(
        'receive_parcel_at_origin_hub',
        params: {'p_parcel_id': parcelId},
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
        message: 'Failed to receive parcel at hub: $e',
      );
    }
  }

  /// Fetches the list of parcels staged at origin hub ready for batch consolidation.
  Future<List<ReadyForBatchParcelDto>> getReadyForBatchParcels() async {
    try {
      final response = await _client.rpc<dynamic>('get_ready_for_batch_parcels');
      final list = (response as List)
          .map((json) =>
              ReadyForBatchParcelDto.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Fetches the authoritative staff profile and authorization state for the current session.
  Future<PersonnelProfileDto> getCurrentPersonnelProfile() async {
    final response = await _client.rpc<dynamic>('get_current_personnel_profile');
    final map = Map<String, dynamic>.from(response as Map);
    return PersonnelProfileDto.fromJson(map);
  }
}
