import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('CereloUser & Role Extraction', () {
    test('extracts role from app_metadata (server-controlled)', () {
      final user = User(
        id: 'user-123',
        appMetadata: {'role': 'customer'},
        userMetadata: {'role': 'admin'}, // Untrusted client-settable metadata
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
      );

      final cereloUser = CereloUser.fromSupabaseUser(user);

      expect(cereloUser.id, equals('user-123'));
      // SECURITY: Must be customer, NOT admin from userMetadata!
      expect(cereloUser.role, equals(ActorRole.customer));
      expect(cereloUser.isCustomer, isTrue);
      expect(cereloUser.isAdmin, isFalse);
      expect(cereloUser.isPersonnel, isFalse);
    });

    test('defaults to customer when role is missing in app_metadata', () {
      final user = User(
        id: 'user-456',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
      );

      final cereloUser = CereloUser.fromSupabaseUser(user);
      expect(cereloUser.role, equals(ActorRole.customer));
    });

    test('extracts personnel role when issued in app_metadata', () {
      final user = User(
        id: 'personnel-789',
        appMetadata: {'role': 'personnel', 'hub_city': 'kano'},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-08-17T00:00:00Z',
      );

      final cereloUser = CereloUser.fromSupabaseUser(user);
      expect(cereloUser.role, equals(ActorRole.personnel));
      expect(cereloUser.isPersonnel, isTrue);
      expect(cereloUser.isCustomer, isFalse);
    });
  });

  group('CereloApiError', () {
    test('parses structured error from JSON correctly', () {
      final json = {
        'code': 'VALIDATION_ERROR',
        'message': 'Business name is required.',
        'field_errors': {'business_name': 'Required'},
        'request_id': 'req-123',
      };

      final error = CereloApiError.tryFromJson(json);

      expect(error, isNotNull);
      expect(error?.code, equals(CereloErrorCode.validationError));
      expect(error?.message, equals('Business name is required.'));
      expect(error?.fieldErrors?['business_name'], equals('Required'));
      expect(error?.requestId, equals('req-123'));
    });
  });
}
