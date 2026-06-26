import 'package:ace_app/core/billing_rules.dart';
import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/models/check_item.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:flutter_test/flutter_test.dart';

CheckSummary _summary({
  required BusinessMode billingMode,
  required int totalTaxIncluded,
  DateTime? createdAt,
  int peopleCount = 1,
}) {
  return CheckSummary(
    id: 'check-1',
    customerId: 'customer-1',
    customerNameSnapshot: 'テスト太郎',
    peopleCount: peopleCount,
    billingMode: billingMode,
    status: 'open',
    totalTaxIncluded: totalTaxIncluded,
    taxAmount: (totalTaxIncluded * 10 / 110).floor(),
    createdAt: createdAt ?? DateTime(2026, 1, 1, 18, 0),
  );
}

CheckItem _item({
  required String name,
  required String category,
  required int lineTotal,
}) {
  return CheckItem(
    id: 'item-$name',
    menuNameSnapshot: name,
    menuCategorySnapshot: category,
    unitPriceTaxIncluded: lineTotal,
    qty: 1,
    lineTotalTaxIncluded: lineTotal,
    orderedAt: DateTime(2026, 1, 1, 18, 10),
  );
}

void main() {
  group('calcTimeCharge', () {
    test('60分以内は1200円', () {
      expect(calcTimeCharge(const Duration(minutes: 60)), 1200);
    });

    test('61分は30分超過1単位で1800円', () {
      expect(calcTimeCharge(const Duration(minutes: 61)), 1800);
    });

    test('90分は30分超過1単位で1800円', () {
      expect(calcTimeCharge(const Duration(minutes: 90)), 1800);
    });

    test('91分は30分超過2単位で2400円', () {
      expect(calcTimeCharge(const Duration(minutes: 91)), 2400);
    });
  });

  group('isMerchandiseByNameAndCategory', () {
    test('DARTS_GOODSカテゴリは物販', () {
      expect(
        isMerchandiseByNameAndCategory(
          name: 'Tシャツ',
          category: 'DARTS_GOODS',
        ),
        isTrue,
      );
    });

    test('自由入力名でもDARTS_GOODSなら物販', () {
      expect(
        isMerchandiseByNameAndCategory(
          name: 'オリジナルフライト',
          category: 'DARTS_GOODS',
        ),
        isTrue,
      );
    });

    test('通常ドリンクは物販ではない', () {
      expect(
        isMerchandiseByNameAndCategory(
          name: 'レモンサワー',
          category: 'SAKE',
        ),
        isFalse,
      );
    });
  });

  group('buildBillingBreakdown', () {
    test('イベント営業は時間料金なし', () {
      final summary = _summary(
        billingMode: BusinessMode.event,
        totalTaxIncluded: 3000,
        createdAt: DateTime(2026, 1, 1, 18, 0),
      );
      final items = [
        _item(name: 'ビール', category: 'BEER', lineTotal: 3000),
      ];
      final breakdown = buildBillingBreakdown(
        summary: summary,
        items: items,
        now: DateTime(2026, 1, 1, 20, 0),
      );

      expect(breakdown.timeCharge, 0);
      expect(breakdown.foodAndBeverageTotal, 3000);
      expect(breakdown.normalTotal, 3000);
    });

    test('通常営業は時間料金を加算する', () {
      final summary = _summary(
        billingMode: BusinessMode.normal,
        totalTaxIncluded: 5000,
        createdAt: DateTime(2026, 1, 1, 18, 0),
        peopleCount: 2,
      );
      final items = [
        _item(name: 'テキーラ', category: 'TEQUILA', lineTotal: 5000),
      ];
      final breakdown = buildBillingBreakdown(
        summary: summary,
        items: items,
        now: DateTime(2026, 1, 1, 19, 0),
      );

      expect(breakdown.timeChargePerPerson, 1200);
      expect(breakdown.timeCharge, 2400);
      expect(breakdown.foodAndBeverageTotal, 7400);
      expect(breakdown.merchandiseTotal, 0);
    });

    test('物販は飲食合計から分離される', () {
      final summary = _summary(
        billingMode: BusinessMode.normal,
        totalTaxIncluded: 8000,
        createdAt: DateTime(2026, 1, 1, 18, 0),
      );
      final items = [
        _item(name: 'テキーラ', category: 'TEQUILA', lineTotal: 5000),
        _item(name: 'Tシャツ', category: 'DARTS_GOODS', lineTotal: 3000),
      ];
      final breakdown = buildBillingBreakdown(
        summary: summary,
        items: items,
        now: DateTime(2026, 1, 1, 18, 30),
      );

      expect(breakdown.merchandiseTotal, 3000);
      expect(breakdown.foodAndBeverageTotal, 6200);
      expect(breakdown.normalTotal, 9200);
    });
  });
}
