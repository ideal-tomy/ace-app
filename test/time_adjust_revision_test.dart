import 'package:ace_app/core/billing_rules.dart';
import 'package:ace_app/features/checkout/time_adjust_card.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

final now = DateTime(2026, 10, 21, 20, 2);
CheckSummary summary({
  int? minutes,
  int people = 1,
  int items = 0,
  DateTime? start,
  DateTime? nomihodai,
  String mode = 'normal',
}) => CheckSummary.fromMap('visit', {
  'customerNameSnapshot': 'テスト',
  'customerId': 'test',
  'peopleCount': people,
  'billingMode': mode,
  'status': 'open',
  'totalTaxIncluded': items,
  'createdAt': Timestamp.fromDate(start ?? DateTime(2026, 10, 21, 20)),
  'billingBilledMinutes': minutes,
  if (nomihodai != null) 'nomihodaiStartedAt': Timestamp.fromDate(nomihodai),
});

void main() {
  test('既存の整数分切捨てと30分境界を維持する', () {
    for (final row in [
      (const Duration(minutes: 60), 1200, 60),
      (const Duration(minutes: 60, seconds: 1), 1200, 60),
      (const Duration(minutes: 60, seconds: 59), 1200, 60),
      (const Duration(minutes: 61), 1800, 90),
      (const Duration(minutes: 90), 1800, 90),
      (const Duration(minutes: 90, seconds: 1), 1800, 90),
      (const Duration(minutes: 91), 2400, 120),
      (const Duration(minutes: 120), 2400, 120),
    ]) {
      expect(calcTimeCharge(row.$1), row.$2);
      expect(billedMinutesFor(row.$1), row.$3);
    }
  });
  test('手動上限は通常起算から閉店3時までの既存請求枠', () {
    expect(
      maxManualBilledMinutes(summary(start: DateTime(2026, 10, 21, 18, 10))),
      540,
    );
    expect(
      maxManualBilledMinutes(
        summary(
          start: DateTime(2026, 10, 21, 18, 10),
          nomihodai: DateTime(2026, 10, 21, 19, 10),
        ),
      ),
      480,
    );
    expect(
      maxManualBilledMinutes(summary(start: DateTime(2026, 10, 22, 2, 58))),
      60,
    );
    expect(maxManualBilledMinutes(summary(mode: 'event')), 0);
  });
  test('手動60/90/120/150分・人数・商品代・調整差額の整合性', () {
    for (final people in [1, 3]) {
      for (final items in [0, 900]) {
        for (final minutes in [60, 90, 120, 150]) {
          final result = buildBillingBreakdown(
            summary: summary(minutes: minutes, people: people, items: items),
            items: [],
            now: now,
          );
          final charge = (1200 + (minutes - 60) ~/ 30 * 600) * people;
          expect(result.timeCharge, charge);
          expect(result.timeChargeAdjustment, 1200 * people - charge);
          expect(result.grandTotal, items + charge);
          expect(result.normalItemsTotal, items);
          expect(result.billingElapsed, const Duration(minutes: 2));
        }
      }
    }
  });
  for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
    testWidgets('${width.toInt()}px 30分増減と自動復帰で料金表示も更新', (tester) async {
      tester.view.physicalSize = Size(width, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? selected;
      final changes = <int?>[];
      final money = NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  final check = summary(
                    minutes: selected,
                    people: 2,
                    items: 900,
                  );
                  return TimeAdjustCard(
                    summary: check,
                    breakdown: buildBillingBreakdown(
                      summary: check,
                      items: [],
                      now: now,
                    ),
                    currency: money,
                    enabled: true,
                    onChanged: (value) async {
                      setState(() {
                        selected = value;
                        changes.add(value);
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '−30分'))
            .onPressed,
        isNull,
      );
      for (final minutes in [90, 120, 150]) {
        await tester.tap(find.text('＋30分'));
        await tester.pumpAndSettle();
        expect(
          find.text(formatStayDuration(Duration(minutes: minutes))),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('−30分'));
      await tester.pumpAndSettle();
      expect(selected, 120);
      await tester.ensureVisible(find.text('自動に戻す'));
      await tester.tap(find.text('自動に戻す'));
      await tester.pumpAndSettle();
      expect(
        find.text(formatStayDuration(Duration(minutes: 60))),
        findsOneWidget,
      );
      expect(changes, [90, 120, 150, 120, null]);
      expect(tester.takeException(), isNull);
    });
  }
}
