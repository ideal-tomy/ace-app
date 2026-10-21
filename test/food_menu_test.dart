import 'package:ace_app/core/food_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasDuplicateFoodName', () {
    test('前後空白や英字の大小が違っても同名として扱う', () {
      expect(hasDuplicateFoodName(['唐揚げ'], ' 唐揚げ　'), isTrue);
      expect(hasDuplicateFoodName(['Fish & Chips'], 'fish  &  chips'), isTrue);
    });

    test('別名は重複ではない', () {
      expect(hasDuplicateFoodName(['唐揚げ'], '唐揚げ（大）'), isFalse);
      expect(hasDuplicateFoodName(const [], '唐揚げ'), isFalse);
    });
  });

  test('isFoodOrderCategory は常設・手打ちのみ', () {
    expect(isFoodOrderCategory('FOOD'), isTrue);
    expect(isFoodOrderCategory('FOOD_DAILY'), isTrue);
    expect(isFoodOrderCategory('BEER'), isFalse);
  });
}
