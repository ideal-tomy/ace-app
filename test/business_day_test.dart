import 'package:ace_app/core/business_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('businessDateFor', () {
    test('05:59 JST belongs to the previous business day', () {
      final result = businessDateFor(DateTime.utc(2026, 8, 5, 20, 59));
      expect(businessDateKey(result), '2026-08-05');
    });

    test('06:00 JST starts the new business day', () {
      final result = businessDateFor(DateTime.utc(2026, 8, 5, 21));
      expect(businessDateKey(result), '2026-08-06');
    });

    test('before and after midnight can share one business day', () {
      final beforeMidnight = businessDateFor(DateTime.utc(2026, 8, 6, 14));
      final afterMidnight = businessDateFor(DateTime.utc(2026, 8, 6, 18));
      expect(businessDateKey(beforeMidnight), '2026-08-06');
      expect(businessDateKey(afterMidnight), '2026-08-06');
    });
  });
}
