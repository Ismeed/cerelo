import 'package:cerelo_core/cerelo_core.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('fromNaira creates correct kobo value', () {
      final money = Money.fromNaira(3000);
      expect(money.kobo, equals(300000));
    });

    test('formatted displays Naira symbol and comma separators', () {
      expect(Money.fromNaira(3000).formatted, equals('₦3,000'));
      expect(Money.fromNaira(10500).formatted, equals('₦10,500'));
    });

    test('addition works correctly', () {
      final a = Money.fromNaira(1500);
      final b = Money.fromNaira(1500);
      expect((a + b).kobo, equals(Money.fromNaira(3000).kobo));
    });

    test('zero is equal to Money.fromNaira(0)', () {
      expect(Money.zero, equals(Money.fromNaira(0)));
    });

    test('negative money throws assertion error', () {
      expect(() => Money.fromKobo(-1), throwsA(isA<AssertionError>()));
    });
  });

  group('PhoneNumber', () {
    test('parses local format (08012345678)', () {
      final phone = PhoneNumber.tryParse('08012345678');
      expect(phone?.e164, equals('+2348012345678'));
    });

    test('parses E.164 format (+2348012345678)', () {
      final phone = PhoneNumber.tryParse('+2348012345678');
      expect(phone?.e164, equals('+2348012345678'));
    });

    test('returns null for invalid number', () {
      expect(PhoneNumber.tryParse('12345'), isNull);
    });

    test('masked hides middle digits', () {
      final phone = PhoneNumber.tryParse('+2348012345678');
      expect(phone?.masked, contains('***'));
    });
  });

  group('DeliveryCode', () {
    test('valid format is accepted', () {
      final code = DeliveryCode.tryParse('CRL-8F2K-9P3N');
      expect(code, isNotNull);
      expect(code?.value, equals('CRL-8F2K-9P3N'));
    });

    test('invalid format returns null', () {
      expect(DeliveryCode.tryParse('invalid'), isNull);
      expect(DeliveryCode.tryParse('CRL-123-456'), isNull);
    });

    test('normalizes lowercase input', () {
      final code = DeliveryCode.tryParse('crl-8f2k-9p3n');
      expect(code?.value, equals('CRL-8F2K-9P3N'));
    });
  });
}
