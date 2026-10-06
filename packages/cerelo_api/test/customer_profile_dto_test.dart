import 'package:cerelo_api/cerelo_api.dart';
import 'package:cerelo_core/cerelo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerProfileDto', () {
    test('deserializes JSON correctly for Individual with completed onboarding',
        () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111111',
        'email': 'customer@cerelo.com',
        'full_name': 'Aliyu Kano',
        'phone_number': '+2348012345678',
        'account_type': 'INDIVIDUAL',
        'business_name': null,
        'is_active': true,
        'onboarding_completed_at': '2026-08-17T10:00:00Z',
        'created_at': '2026-08-17T09:00:00Z',
        'updated_at': '2026-08-17T10:00:00Z',
      };

      final dto = CustomerProfileDto.fromJson(json);

      expect(dto.id, equals('11111111-1111-1111-1111-111111111111'));
      expect(dto.email, equals('customer@cerelo.com'));
      expect(dto.fullName, equals('Aliyu Kano'));
      expect(dto.accountType, equals(AccountType.individual));
      expect(dto.isBusiness, isFalse);
      expect(dto.businessName, isNull);
      expect(dto.isOnboardingComplete, isTrue);
      expect(dto.isActive, isTrue);
    });

    test('deserializes JSON correctly for Business with incomplete onboarding',
        () {
      final json = {
        'id': '22222222-2222-2222-2222-222222222222',
        'email': 'trader@kwari.ng',
        'full_name': 'Fatima Katsina',
        'phone_number': null,
        'account_type': 'BUSINESS',
        'business_name': 'Kwari Textiles',
        'is_active': true,
        'onboarding_completed_at': null,
      };

      final dto = CustomerProfileDto.fromJson(json);

      expect(dto.id, equals('22222222-2222-2222-2222-222222222222'));
      expect(dto.accountType, equals(AccountType.business));
      expect(dto.isBusiness, isTrue);
      expect(dto.businessName, equals('Kwari Textiles'));
      expect(dto.isOnboardingComplete, isFalse);
    });

    test('toJson serializes correctly', () {
      final completedAt = DateTime.parse('2026-08-17T12:00:00Z');
      const dto = CustomerProfileDto(
        id: '33333333-3333-3333-3333-333333333333',
        email: 'test@example.com',
        fullName: 'Bello Garba',
        accountType: AccountType.business,
        businessName: 'Garba Electronics',
        onboardingCompletedAt: null,
      );

      final json = dto.copyWith(onboardingCompletedAt: completedAt).toJson();

      expect(json['id'], equals('33333333-3333-3333-3333-333333333333'));
      expect(json['email'], equals('test@example.com'));
      expect(json['full_name'], equals('Bello Garba'));
      expect(json['account_type'], equals('BUSINESS'));
      expect(json['business_name'], equals('Garba Electronics'));
      expect(json['onboarding_completed_at'], isNotNull);
    });

    test('equality and copyWith work as expected', () {
      const dto1 = CustomerProfileDto(
        id: '1',
        fullName: 'Name',
        accountType: AccountType.individual,
      );
      const dto2 = CustomerProfileDto(
        id: '1',
        fullName: 'Name',
        accountType: AccountType.individual,
      );

      expect(dto1, equals(dto2));
      expect(dto1.hashCode, equals(dto2.hashCode));

      final updated = dto1.copyWith(
        accountType: AccountType.business,
        businessName: 'Shop',
      );
      expect(updated.accountType, equals(AccountType.business));
      expect(updated.businessName, equals('Shop'));
      expect(updated, isNot(equals(dto1)));
    });
  });
}
