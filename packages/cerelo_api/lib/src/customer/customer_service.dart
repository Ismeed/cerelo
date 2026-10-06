import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer Service — provides customer profile resolution, onboarding completion,
/// and profile update operations.
///
/// SECURITY:
/// - Executes authoritatively on the backend using PostgreSQL RPCs.
/// - Does not execute direct table UPDATE queries from the client.
/// - Validates authentication state before calling RPCs.
class CustomerService {
  CustomerService({SupabaseClient? client})
      : _client = client ?? CereloSupabaseClient.instance;

  final SupabaseClient _client;

  /// Fetches and resolves the current authenticated customer's profile.
  ///
  /// Calls the `get_current_customer` RPC which idempotently resolves
  /// or initializes the customer record if absent.
  Future<CustomerProfileDto> getCurrentProfile() async {
    try {
      final response = await _client.rpc('get_current_customer');
      if (response == null) {
        throw const CereloApiError(
          code: CereloErrorCode.notFound,
          message: 'Customer profile could not be found or initialized.',
        );
      }
      return CustomerProfileDto.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to load customer profile: $e',
      );
    }
  }

  /// Completes customer onboarding atomically.
  ///
  /// Calls `complete_customer_onboarding` RPC.
  /// Validates that:
  /// - If [accountType] is Business, [businessName] is non-empty.
  /// - [fullName] is updated if provided.
  Future<CustomerProfileDto> completeOnboarding({
    required AccountType accountType,
    String? businessName,
    String? fullName,
  }) async {
    // Client-side pre-validation for immediate UX feedback
    if (accountType == AccountType.business) {
      if (businessName == null || businessName.trim().isEmpty) {
        throw const CereloApiError(
          code: CereloErrorCode.validationError,
          message: 'Please enter your business or shop name.',
          fieldErrors: {'business_name': 'Business/Shop Name is required'},
        );
      }
    }

    try {
      final response = await _client.rpc(
        'complete_customer_onboarding',
        params: {
          'p_account_type': accountType.name.toUpperCase(),
          'p_business_name': businessName?.trim(),
          'p_full_name': fullName?.trim(),
        },
      );

      return CustomerProfileDto.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to complete onboarding: $e',
      );
    }
  }

  /// Updates editable customer profile fields (Full Name, Business Name).
  ///
  /// Calls `update_customer_profile` RPC.
  Future<CustomerProfileDto> updateProfile({
    String? fullName,
    String? businessName,
  }) async {
    try {
      final response = await _client.rpc(
        'update_customer_profile',
        params: {
          'p_full_name': fullName?.trim(),
          'p_business_name': businessName?.trim(),
        },
      );

      return CustomerProfileDto.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    } catch (e) {
      if (e is CereloApiError) rethrow;
      throw CereloApiError(
        code: CereloErrorCode.internalError,
        message: 'Failed to update profile: $e',
      );
    }
  }

  CereloApiError _mapPostgrestError(PostgrestException e) {
    final message = e.message;
    if (message.contains('UNAUTHENTICATED')) {
      return const CereloApiError(
        code: CereloErrorCode.unauthenticated,
        message: 'Please sign in to continue.',
      );
    }
    if (message.contains('VALIDATION_ERROR')) {
      return CereloApiError(
        code: CereloErrorCode.validationError,
        message: message.replaceFirst(RegExp(r'^VALIDATION_ERROR:\s*'), ''),
      );
    }
    if (message.contains('NOT_FOUND')) {
      return const CereloApiError(
        code: CereloErrorCode.notFound,
        message: 'Customer profile not found.',
      );
    }
    return CereloApiError(
      code: CereloErrorCode.internalError,
      message: 'A database error occurred. Please try again.',
    );
  }
}
