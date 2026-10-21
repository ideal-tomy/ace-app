import 'dart:io';
import 'dart:ui' as ui;

import 'package:ace_app/core/billing_rules.dart';
import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/data/repositories/check_repository.dart';
import 'package:ace_app/features/checkout/time_adjust_card.dart';
import 'package:ace_app/features/checkout/checkout_detail_sheet.dart';
import 'package:ace_app/features/order/order_flow_sheet.dart';
import 'package:ace_app/features/order/widgets/order_menu_step.dart';
import 'package:ace_app/features/order/order_flow_state.dart';
import 'package:ace_app/features/shared/person_picker_list.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:ace_app/models/person_option.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/improvement_fixtures.dart';
import 'support/memory_firestore.dart';

const captureStage = String.fromEnvironment('UI_REVISION_CAPTURE');
const before = captureStage == 'before';
final currency = NumberFormat.currency(
  locale: 'ja_JP',
  symbol: '¥',
  decimalDigits: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  setUpAll(() async {
    for (final entry in {
      'Meiryo': 'C:/Windows/Fonts/meiryo.ttc',
      'MaterialIcons': 'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        await (FontLoader(entry.key)..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())),
            ))
            .load();
      }
    }
  });
  Future<void> show(
    WidgetTester tester,
    Widget widget,
    double width,
    double height,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, fontFamily: 'Meiryo'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: widget,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (captureStage.isEmpty) return;
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui-revision-2026-10-21/$captureStage-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('来店者カード ${width.toInt()}px 文字倍率$scale', (tester) async {
        await show(
          tester,
          Scaffold(
            body: PersonPickerList(
              people: [
                for (var i = 0; i < 4; i++)
                  PersonOption(
                    customerId: '$i',
                    displayName: 'とても長い名前のお客様$i',
                    openCheckId: '$i',
                    createdAtMillis: DateTime(
                      2026,
                      10,
                      21,
                      18,
                    ).millisecondsSinceEpoch,
                    billingMode: BusinessMode.normal,
                    switchedFromEvent: i == 0,
                    peopleCount: 3,
                  ),
              ],
              onPersonSelected: (_) {},
            ),
          ),
          width,
          667,
          scale,
        );
        final error = tester.takeException();
        if (before && (width <= 375 || scale > 1)) {
          expect(error, isNotNull, reason: '固定比率カードの高さ不足を再現');
        } else if (!before) {
          expect(error, isNull);
          expect(find.text('3名').hitTestable(), findsWidgets);
          expect(find.text('入店 18:00').hitTestable(), findsWidgets);
        }
        if (width == 320 && scale == 1.0) {
          await capture(tester, 'people-320');
        }
        if (width == 320 && scale == 1.5) {
          await capture(tester, 'people-320-scale150');
        }
      });
    }
    for (final height in [667.0, 844.0]) {
      for (final scale in [1.0, 1.5]) {
        for (final mode in BusinessMode.values) {
          testWidgets(
            '会計シート ${width.toInt()}x${height.toInt()} 文字倍率$scale ${mode.name}',
            (tester) async {
              final store = MemoryFirestore();
              store.documents['stores/test/checks/visit'] = {
                'customerNameSnapshot': 'テスト',
                'peopleCount': 2,
                'customerId': 'test',
                'status': 'open',
                'billingMode': mode.firestoreValue,
                'totalTaxIncluded': 900,
                'createdAt': Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(minutes: 67)),
                ),
              };
              store.documents['stores/test/checks/visit/items/item'] = {
                'menuNameSnapshot': 'テストフード',
                'menuCategorySnapshot': 'FOOD',
                'qty': 1,
                'unitPriceTaxIncluded': 900,
                'lineTotalTaxIncluded': 900,
                'orderedAt': Timestamp.now(),
                'billedAs': mode.firestoreValue,
              };
              await show(
                tester,
                Scaffold(
                  body: CheckoutDetailSheet(
                    person: PersonOption(
                      customerId: 'test',
                      displayName: 'テスト',
                      openCheckId: 'visit',
                      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
                      billingMode: mode,
                    ),
                    checkRepository: CheckRepository(
                      firestore: store,
                      storeId: 'test',
                    ),
                    canOperate: true,
                  ),
                ),
                width,
                height,
                scale,
              );
              expect(tester.takeException(), isNull);
              final contentScroll = find
                  .descendant(
                    of: find.byType(CheckoutDetailSheet),
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await tester.scrollUntilVisible(
                find.text('現金'),
                180,
                scrollable: contentScroll,
              );
              await tester.tap(find.text('現金'));
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.text('テストフード'),
                180,
                scrollable: contentScroll,
              );
              await tester.pumpAndSettle();
              expect(find.text('会計確定').hitTestable(), findsOneWidget);
              if (width == 320 &&
                  height == 667 &&
                  scale == 1 &&
                  mode == BusinessMode.normal) {
                await capture(tester, 'checkout-320');
              }
              expect(tester.takeException(), isNull);
              expect(
                store.documents['stores/test/checks/visit']!['status'],
                'open',
              );
            },
          );
        }
      }
      for (final mode in BusinessMode.values) {
        testWidgets('フード末尾 ${width.toInt()}x${height.toInt()} ${mode.name}', (
          tester,
        ) async {
          final store = MemoryFirestore();
          store.documents['stores/test/checks/visit'] = {
            'customerNameSnapshot': 'テスト',
            'status': 'open',
            'billingMode': mode.firestoreValue,
            'createdAt': Timestamp.now(),
          };
          final menus = FixtureMenus();
          menus.all.removeWhere((m) => m.category == 'FOOD');
          menus.all.addAll([
            for (var i = 1; i <= 10; i++)
              menu('food$i', 'フード$i', 'FOOD', 300 + i * 100),
          ]);
          final checks = CheckRepository(firestore: store, storeId: 'test');
          await show(
            tester,
            Scaffold(
              body: OrderFlowSheet(
                checkRepository: checks,
                menuRepository: menus,
                adminAuthService: StaffAuth(),
                initialState: OrderFlowState(
                  person: PersonOption(
                    customerId: 'test',
                    displayName: 'テスト',
                    openCheckId: 'visit',
                    createdAtMillis: DateTime.now().millisecondsSinceEpoch,
                    billingMode: mode,
                  ),
                ),
              ),
            ),
            width,
            height,
            1,
          );
          await tester.tap(find.text('フード'));
          await tester.pumpAndSettle();
          if (width == 320 && height == 667 && mode == BusinessMode.normal) {
            await capture(tester, 'food-top-320');
          }
          final lastMenu = find.descendant(
            of: find.byType(GridView),
            matching: find.text('フード10'),
          );
          final lastButton = find.ancestor(
            of: lastMenu,
            matching: find.byType(FilledButton),
          );
          await tester.scrollUntilVisible(
            lastMenu,
            160,
            scrollable: find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.ensureVisible(lastButton);
          await tester.pumpAndSettle();
          await tester.tap(lastButton);
          await tester.pumpAndSettle();
          expect(find.textContaining('1点'), findsOneWidget);
          // カート展開でグリッドが縮むため、展開後にも末尾へスクロールする。
          await tester.scrollUntilVisible(
            lastMenu,
            100,
            scrollable: find.descendant(
              of: find.byType(GridView),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.ensureVisible(lastButton);
          await tester.pumpAndSettle();
          final menuBottom = tester.getBottomLeft(lastButton).dy;
          final managementTop = tester.getTopLeft(find.text('フードメニューを管理')).dy;
          expect(menuBottom, lessThan(managementTop));
          if (width == 320 && height == 667 && mode == BusinessMode.normal) {
            await capture(tester, 'food-last-320');
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final foodWidth in [320.0, 360.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('長いフード名の2行表示 ${foodWidth.toInt()}px 文字倍率$scale', (
        tester,
      ) async {
        final menus = FixtureMenus();
        menus.all.clear();
        menus.all.add(menu('long-food', '鶏の唐揚げ・タルタルソース添え', 'FOOD', 900));
        await show(
          tester,
          Scaffold(
            body: OrderMenuStep(
              person: PersonOption(
                customerId: 'test',
                displayName: 'テスト',
                openCheckId: 'visit',
                createdAtMillis: 0,
              ),
              checkRepository: CheckRepository(
                firestore: MemoryFirestore(),
                storeId: 'test',
              ),
              menuRepository: menus,
              adminAuthService: StaffAuth(),
              onMenuSelected: (_) {},
              onCustomMenuSelected: (_) {},
            ),
          ),
          foodWidth,
          667,
          scale,
        );
        await tester.tap(find.text('フード'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('会計UI→時間保存→料金再表示→確定スナップショット', (tester) async {
    final store = MemoryFirestore();
    addTearDown(store.dispose);
    final created = DateTime.now().subtract(const Duration(minutes: 2));
    store.documents['stores/test/checks/visit'] = {
      'customerNameSnapshot': 'テスト',
      'customerId': 'test',
      'peopleCount': 2,
      'status': 'open',
      'billingMode': 'normal',
      'totalTaxIncluded': 900,
      'createdAt': Timestamp.fromDate(created),
    };
    store.documents['stores/test/checks/visit/items/food'] = {
      'menuNameSnapshot': 'フード',
      'menuCategorySnapshot': 'FOOD',
      'unitPriceTaxIncluded': 900,
      'qty': 1,
      'lineTotalTaxIncluded': 900,
      'orderedAt': Timestamp.now(),
      'billedAs': 'normal',
    };
    final checks = CheckRepository(firestore: store, storeId: 'test');
    final initial = CheckSummary.fromMap(
      'visit',
      store.documents['stores/test/checks/visit']!,
    );
    final maximum = maxManualBilledMinutes(initial);
    await show(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showCheckoutDetailSheet(
              context,
              person: PersonOption(
                customerId: 'test',
                displayName: 'テスト',
                openCheckId: 'visit',
                createdAtMillis: created.millisecondsSinceEpoch,
              ),
              checkRepository: checks,
              canOperate: true,
            ),
            child: const Text('テスト会計を開く'),
          ),
        ),
      ),
      320,
      667,
      1,
    );
    await tester.tap(find.text('テスト会計を開く'));
    await tester.pumpAndSettle();
    final contentScroll = find
        .descendant(
          of: find.byType(CheckoutDetailSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('＋30分'),
      180,
      scrollable: contentScroll,
    );
    if (maximum > 60) {
      await tester.tap(find.text('＋30分'));
      await tester.pumpAndSettle();
      expect(
        store.documents['stores/test/checks/visit']!['billingBilledMinutes'],
        90,
      );
      expect(find.text(currency.format(4500)), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('現金'),
      180,
      scrollable: contentScroll,
    );
    await tester.tap(find.text('現金'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('会計確定'));
    await tester.pumpAndSettle();
    final paid = store.documents['stores/test/checks/visit']!;
    expect(paid['status'], 'paid');
    expect(paid['finalAmount'], maximum > 60 ? 4500 : 3300);
    expect(paid['billingBilledMinutesFinal'], maximum > 60 ? 90 : 60);
    expect(paid['timeChargeAdjustmentAmount'], maximum > 60 ? -1200 : 0);
    expect(paid['totalTaxIncluded'], 900);
    expect(tester.takeException(), isNull);
  });

  testWidgets('入店2分の時間調整表示', (tester) async {
    int? manual;
    final created = DateTime.now().subtract(const Duration(minutes: 2));
    CheckSummary current() => CheckSummary(
      id: 'visit',
      customerId: 'test',
      customerNameSnapshot: 'テスト',
      peopleCount: 1,
      billingMode: BusinessMode.normal,
      status: 'open',
      totalTaxIncluded: 0,
      taxAmount: 0,
      createdAt: created,
      billingBilledMinutes: manual,
    );
    await show(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) {
              final check = current();
              return TimeAdjustCard(
                summary: check,
                breakdown: buildBillingBreakdown(
                  summary: check,
                  items: [],
                  now: DateTime.now(),
                ),
                currency: currency,
                enabled: true,
                onChanged: (minutes) async {
                  setState(() => manual = minutes);
                },
              );
            },
          ),
        ),
      ),
      320,
      667,
      1,
    );
    if (before) {
      await tester.tap(find.text('変更'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsOneWidget);
    }
    await capture(tester, 'time-320');
    if (!before) {
      await tester.tap(find.text('＋30分'));
      await tester.pumpAndSettle();
      expect(find.text('1時間30分'), findsOneWidget);
      await capture(tester, 'time-increased-320');
    }
    expect(tester.takeException(), isNull);
  });
}
