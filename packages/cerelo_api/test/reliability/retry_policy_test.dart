import 'package:cerelo_api/cerelo_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy', () {
    test('classifies socket / connection errors as transient', () {
      final category = RetryPolicy.classify('SocketException: Connection refused');
      expect(category, equals(FailureCategory.transient));
    });

    test('classifies timeouts as unknownOutcome', () {
      final category = RetryPolicy.classify('TimeoutException after 0:00:10.000000');
      expect(category, equals(FailureCategory.unknownOutcome));
    });

    test('classifies validation / auth / business errors as permanent', () {
      final category = RetryPolicy.classify('Invalid payment amount or authorization failed');
      expect(category, equals(FailureCategory.permanent));
    });

    test('calculates exponential backoff with positive delay', () {
      final delay1 = RetryPolicy.calculateBackoff(1);
      final delay2 = RetryPolicy.calculateBackoff(2);
      final delay3 = RetryPolicy.calculateBackoff(3);

      expect(delay1.inMilliseconds, greaterThanOrEqualTo(1000));
      expect(delay2.inMilliseconds, greaterThanOrEqualTo(2000));
      expect(delay3.inMilliseconds, greaterThanOrEqualTo(4000));
    });
  });
}
