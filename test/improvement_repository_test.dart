import 'package:ace_app/core/payment_method.dart';
import 'package:ace_app/data/repositories/check_repository.dart';
import 'package:ace_app/data/repositories/menu_repository.dart';
import 'package:ace_app/data/repositories/sales_summary_repository.dart';
import 'package:ace_app/core/business_day.dart';
import 'package:ace_app/features/shared/check_billing_utils.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_firestore.dart';
import 'support/improvement_fixtures.dart';

const checkPath = 'stores/test/checks/visit';
final checkoutNow = DateTime(2026, 10, 21, 20);

Map<String, dynamic> openCheck({String mode = 'normal', int? override}) => {
  'customerNameSnapshot': 'テスト',
  'customerId': 'customer',
  'peopleCount': 1,
  'billingMode': mode,
  'status': 'open',
  'totalTaxIncluded': 1400,
  'taxAmount': 127,
  'createdAt': Timestamp.fromDate(
    checkoutNow.subtract(const Duration(minutes: 67)),
  ),
  'billingBilledMinutes': ?override,
};

void main() {
  late MemoryFirestore store;
  late CheckRepository checks;
  setUp(() {
    store = MemoryFirestore();
    checks = CheckRepository(
      firestore: store,
      storeId: 'test',
      now: () => checkoutNow,
    );
    store.documents[checkPath] = openCheck(override: 60);
    for (final entry in [
      ('food', 'FOOD', 400),
      ('goods', 'DARTS_GOODS', 1000),
    ]) {
      store.documents['$checkPath/items/${entry.$1}'] = {
        'menuNameSnapshot': entry.$1,
        'menuCategorySnapshot': entry.$2,
        'unitPriceTaxIncluded': entry.$3,
        'qty': 1,
        'lineTotalTaxIncluded': entry.$3,
        'orderedAt': Timestamp.now(),
        'billedAs': 'normal',
      };
    }
  });

  test('67分から30分枠をサービスし、自動枠と確定枠・商品価格を保存する', () async {
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    final paid = store.documents[checkPath]!;
    expect(paid['status'], 'paid');
    expect(paid['actualStayMinutesFinal'], 67);
    expect(paid['billingAutoBilledMinutesFinal'], 90);
    expect(paid['billingBilledMinutesFinal'], 60);
    expect(paid['timeChargeAutoFinal'], 1800);
    expect(paid['timeChargeFinal'], 1200);
    expect(paid['timeChargeAdjustmentAmount'], 600);
    expect(paid['merchandiseFinal'], 1000);
    expect(paid['totalTaxIncluded'], 1400);
    expect(paid['finalAmount'], 2600);
  });

  test('自動のまま会計しても確定時間が保存される', () async {
    store.documents[checkPath] = openCheck();
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    expect(store.documents[checkPath]!['billingBilledMinutesFinal'], 90);
    expect(store.documents[checkPath]!['billingAutoBilledMinutesFinal'], 90);
    expect(store.documents[checkPath]!['timeChargeAdjustmentAmount'], 0);
  });

  test('フード登録→注文→商品削除→会計→日次締めで注文時単価・売上を保持する', () async {
    store.documents.clear();
    store.documents[checkPath] = {
      ...openCheck(mode: 'event'),
      'totalTaxIncluded': 0,
    };
    final menus = MenuRepository(firestore: store, storeId: 'test');
    await menus.addFoodMenu(name: '枝豆', priceTaxIncluded: 300);
    final food = (await menus.streamActiveFoodMenus().first).single;
    await checks.addOrderItem(checkId: 'visit', menu: food, qty: 2);
    await menus.deleteMenu(food.id);
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    final paid = CheckSummary.fromMap('visit', store.documents[checkPath]!);
    final sales = SalesSummaryRepository(
      firestore: store,
      auth: SignedInAuth(),
      storeId: 'test',
    );
    final day = businessDateFor(checkoutNow);
    await sales.closeBusinessDay(businessDate: day, paidChecks: [paid]);
    final closingPath = 'stores/test/daily_closings/${businessDateKey(day)}';
    expect(store.documents[closingPath]!['totalSales'], 600);
    expect(store.documents['$closingPath/checks/visit']!['finalAmount'], 600);
    final item = store.documents.entries
        .singleWhere((e) => e.key.startsWith('$checkPath/items/'))
        .value;
    expect(item['unitPriceTaxIncluded'], 300);
    expect(item['qty'], 2);
    await checks.updateDepartedAt(
      checkId: 'visit',
      departedAt: checkoutNow.subtract(const Duration(minutes: 5)),
      correctedBy: 'staff',
    );
    final corrected = CheckSummary.fromMap(
      'visit',
      store.documents[checkPath]!,
    );
    expect(sales.amountOf(corrected), 600);
    expect(store.documents[closingPath]!['totalSales'], 600);
    await expectLater(
      sales.closeBusinessDay(businessDate: day, paidChecks: [corrected]),
      throwsStateError,
    );
    expect(store.documents[closingPath]!['totalSales'], 600);
  });

  test('イベント会計に時間料金を加えない', () async {
    store.documents[checkPath] = openCheck(mode: 'event');
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    expect(store.documents[checkPath]!['billingAutoBilledMinutesFinal'], 0);
    expect(store.documents[checkPath]!['billingBilledMinutesFinal'], 0);
    expect(store.documents[checkPath]!['timeChargeFinal'], 0);
    expect(store.documents[checkPath]!['finalAmount'], 1400);
  });

  test('会計後の訂正は退店時刻と履歴のみ、売上・請求枠・会計時刻を固定する', () async {
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    final before = Map<String, dynamic>.of(store.documents[checkPath]!);
    final corrected = checkoutNow.subtract(const Duration(minutes: 7));
    await checks.updateDepartedAt(
      checkId: 'visit',
      departedAt: corrected,
      correctedBy: 'staff',
    );
    final after = store.documents[checkPath]!;
    expect({...after}..remove('departedAt'), {...before}..remove('departedAt'));
    final correction = store.documents.entries
        .singleWhere((e) => e.key.contains('/visit_corrections/'))
        .value;
    expect(correction['fromAt'], before['departedAt']);
    expect(correction['toAt'], Timestamp.fromDate(corrected));
    expect(correction['correctedAt'], isA<Timestamp>());
    expect(
      checkDisplayTotal(
        summary: CheckSummary.fromMap('visit', after),
        items: [],
        now: checkoutNow.add(const Duration(days: 5)),
      ),
      2600,
    );
    await expectLater(
      checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash),
      throwsStateError,
    );
    expect(
      store.documents.keys.where((p) => p.split('/').length == 4),
      hasLength(1),
    );
  });

  test('不整合な時刻や会計済み時間調整を拒否する', () async {
    await expectLater(
      checks.updateBillingBilledMinutes('visit', 65),
      throwsArgumentError,
    );
    await expectLater(
      checks.updateBillingBilledMinutes('visit', 1470),
      throwsArgumentError,
    );
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    await expectLater(
      checks.updateBillingBilledMinutes('visit', 60),
      throwsStateError,
    );
    await expectLater(
      checks.updateDepartedAt(
        checkId: 'visit',
        departedAt: DateTime(2000),
        correctedBy: 'staff',
      ),
      throwsStateError,
    );
    await expectLater(
      checks.updateDepartedAt(
        checkId: 'visit',
        departedAt: checkoutNow.add(const Duration(days: 1)),
        correctedBy: 'staff',
      ),
      throwsStateError,
    );
  });

  test('旧伝票は自動枠の欠落を推測せず読む', () {
    final summary = CheckSummary.fromMap('old', openCheck());
    expect(summary.billingAutoBilledMinutesFinal, isNull);
    expect(summary.billingBilledMinutesFinal, isNull);
  });

  test('自動時間を超えた150分指定は増額として保存、時刻訂正後も固定する', () async {
    store.documents[checkPath]!['peopleCount'] = 2;
    await checks.updateBillingBilledMinutes('visit', 150);
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    final paid = Map<String, dynamic>.of(store.documents[checkPath]!);
    expect(paid['billingAutoBilledMinutesFinal'], 90);
    expect(paid['billingBilledMinutesFinal'], 150);
    expect(paid['actualStayMinutesFinal'], 67);
    expect(paid['timeChargeAutoFinal'], 3600);
    expect(paid['timeChargeFinal'], 6000);
    expect(paid['timeChargeAdjustmentAmount'], -2400);
    expect(paid['finalAmount'], 7400);
    expect(paid['totalTaxIncluded'], 1400);
    await checks.updateDepartedAt(
      checkId: 'visit',
      departedAt: checkoutNow.subtract(const Duration(minutes: 5)),
      correctedBy: 'staff',
    );
    expect(
      {...store.documents[checkPath]!}..remove('departedAt'),
      {...paid}..remove('departedAt'),
    );
    final sales = SalesSummaryRepository(
      firestore: store,
      auth: SignedInAuth(),
      storeId: 'test',
    );
    expect(
      sales.amountOf(
        CheckSummary.fromMap('visit', store.documents[checkPath]!),
      ),
      7400,
    );
  });

  test('手動増額後も自動へ戻せる', () async {
    await checks.updateBillingBilledMinutes('visit', 150);
    await checks.updateBillingBilledMinutes('visit', null);
    await checks.finalizeCheck('visit', paymentMethod: PaymentMethod.cash);
    final paid = store.documents[checkPath]!;
    expect(paid['billingBilledMinutesFinal'], 90);
    expect(paid['timeChargeAdjustmentAmount'], 0);
    expect(paid['finalAmount'], 3200);
  });

  Future<void> addPair(MenuRepository menus) => menus.addMenuPair(
    regularName: 'レモン',
    megaName: 'メガレモン',
    regularCategory: 'SOUR',
    megaCategory: 'SOUR_メガサイズ',
    regularPrice: 550,
    megaPrice: 880,
  );

  test('両サイズは別単価で一括保存される', () async {
    await addPair(MenuRepository(firestore: store, storeId: 'test'));
    final menus = store.documents.entries
        .where((e) => e.key.contains('/menus/'))
        .map((e) => e.value)
        .toList();
    expect(menus.map((m) => m['priceTaxIncluded']), [550, 880]);
    expect(menus.map((m) => m['category']), ['SOUR', 'SOUR_メガサイズ']);
  });

  test('片側の重複または保存失敗なら他方も新規保存されない', () async {
    final menus = MenuRepository(firestore: store, storeId: 'test');
    store.documents['stores/test/menus/existing'] = {
      'name': 'メガレモン',
      'category': 'SOUR_メガサイズ',
      'sortOrder': 10,
    };
    await expectLater(addPair(menus), throwsStateError);
    expect(
      store.documents.keys.where((p) => p.contains('/menus/')),
      hasLength(1),
    );
    store.documents.remove('stores/test/menus/existing');
    store.failBatch = true;
    await expectLater(addPair(menus), throwsStateError);
    expect(store.documents.keys.where((p) => p.contains('/menus/')), isEmpty);
  });
}
