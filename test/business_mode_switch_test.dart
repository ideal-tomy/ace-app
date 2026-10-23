import 'package:ace_app/core/billing_rules.dart';
import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/core/payment_method.dart';
import 'package:ace_app/data/repositories/check_repository.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:ace_app/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_firestore.dart';
import 'support/improvement_fixtures.dart';

void main() {
  testWidgets('ホームから通常→イベントに切替できる', (tester) async {
    final store = MemoryFirestore();
    addTearDown(store.dispose);
    final start = DateTime.now().subtract(const Duration(minutes: 90));
    const path = 'stores/test/checks/check';
    store.documents[path] = {
      'customerNameSnapshot': '切替テスト',
      'billingMode': 'normal',
      'status': 'open',
      'peopleCount': 1,
      'createdAt': Timestamp.fromDate(start),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          checkRepository: CheckRepository(firestore: store, storeId: 'test'),
          adminAuthService: StaffAuth(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('イベント営業に切替'));
    await tester.pumpAndSettle();
    expect(find.textContaining('以後の時間料金を止めます'), findsOneWidget);
    await tester.tap(find.text('切り替える'));
    await tester.pumpAndSettle();
    expect(store.documents[path]!['billingMode'], 'event');
    expect(find.text('通常→イベント'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('通常90分→イベントで時間料金停止、注文の按分と確定金額を保持', () async {
    final store = MemoryFirestore();
    addTearDown(store.dispose);
    final start = DateTime(2026, 10, 23, 18);
    var now = start.add(const Duration(minutes: 90));
    final repo = CheckRepository(
      firestore: store,
      storeId: 'test',
      now: () => now,
    );
    const path = 'stores/test/checks/check';
    store.documents[path] = {
      'billingMode': 'normal',
      'status': 'open',
      'peopleCount': 2,
      'createdAt': Timestamp.fromDate(start),
      'nomihodaiStartedAt': Timestamp.fromDate(start),
      'totalTaxIncluded': 1000,
    };
    for (final entry in [('normal', 400), ('event', 600)]) {
      store.documents['$path/items/${entry.$1}'] = {
        'billedAs': entry.$1,
        'lineTotalTaxIncluded': entry.$2,
        'orderedAt': Timestamp.fromDate(start),
      };
    }
    await repo.switchToEvent('check');
    final summary = CheckSummary.fromMap('check', store.documents[path]!);
    expect(summary.billingMode, BusinessMode.event);
    expect(summary.normalBillingPeriods.single.endedAt, now);
    expect(
      buildBillingBreakdown(summary: summary, items: [], now: now).timeCharge,
      3600,
    );
    now = now.add(const Duration(hours: 3));
    expect(
      buildBillingBreakdown(summary: summary, items: [], now: now).timeCharge,
      3600,
    );
    await expectLater(repo.switchToEvent('check'), throwsStateError);
    await repo.finalizeCheck('check', paymentMethod: PaymentMethod.cash);
    final paid = store.documents[path]!;
    expect(paid['finalAmount'], 4600);
    expect(paid['normalAmountFinal'], 4000);
    expect(paid['eventAmountFinal'], 600);
    expect(paid['billingBilledMinutesFinal'], 90);
    await expectLater(repo.switchToEvent('check'), throwsStateError);
  });

  test('再度通常に戻しても終了済み区間と時間調整を保持', () {
    final start = DateTime(2026, 10, 23, 18);
    final summary = CheckSummary.fromMap('check', {
      'billingMode': 'normal',
      'peopleCount': 1,
      'createdAt': Timestamp.fromDate(start),
      'nomihodaiStartedAt': Timestamp.fromDate(
        start.add(const Duration(hours: 3)),
      ),
      'normalBillingPeriods': [
        {
          'startedAt': Timestamp.fromDate(start),
          'endedAt': Timestamp.fromDate(start.add(const Duration(minutes: 90))),
          'billedMinutes': 60,
        },
      ],
    });
    final result = buildBillingBreakdown(
      summary: summary,
      items: [],
      now: start.add(const Duration(hours: 4)),
    );
    expect(result.timeCharge, 2400);
    expect(result.timeChargeAuto, 3000);
    expect(result.billedMinutes, 120);
    expect(result.autoBilledMinutes, 150);
  });
}
