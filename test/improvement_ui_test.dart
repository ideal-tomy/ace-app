import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/data/repositories/check_repository.dart';
import 'package:ace_app/features/admin/menu_edit_page.dart';
import 'package:ace_app/features/home/home_page.dart';
import 'package:ace_app/features/order/order_flow_sheet.dart';
import 'package:ace_app/features/order/order_flow_state.dart';
import 'package:ace_app/models/person_option.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/improvement_fixtures.dart';
import 'support/memory_firestore.dart';

void main() {
  for (final width in [320.0, 375.0]) {
    testWidgets('${width.toInt()}px ホームの並列ボタン・名前順・検索×', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryFirestore();
      for (final name in ['やまだ', 'あおき']) {
        store.documents['stores/test/checks/$name'] = {
          'customerNameSnapshot': name,
          'peopleCount': 1,
          'billingMode': 'normal',
          'status': 'open',
          'createdAt': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 67)),
          ),
          'totalTaxIncluded': 0,
        };
      }
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
      expect(
        tester.getTopLeft(find.text('来店登録')).dy,
        tester.getTopLeft(find.text('会計')).dy,
      );
      expect(
        tester.getTopLeft(find.text('商品登録')).dy,
        tester.getTopLeft(find.text('日別売上')).dy,
      );
      expect(
        tester.getTopLeft(find.text('あおき')).dy,
        lessThan(tester.getTopLeft(find.text('やまだ')).dy),
      );
      expect(find.textContaining('経過 '), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'やまだ');
      await tester.pump();
      expect(find.text('あおき'), findsNothing);
      await tester.tap(find.byTooltip('検索をクリア'));
      await tester.pump();
      expect(find.text('あおき'), findsOneWidget);
      expect(store.documents.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    for (final mode in BusinessMode.values) {
      testWidgets('${width.toInt()}px ${mode.name} 注文３タブは同じ来店者・カートを維持', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryFirestore();
        store.documents['stores/test/checks/visit'] = {
          'customerNameSnapshot': 'テスト',
          'status': 'open',
          'billingMode': mode.firestoreValue,
          'createdAt': Timestamp.now(),
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OrderFlowSheet(
                checkRepository: CheckRepository(
                  firestore: store,
                  storeId: 'test',
                ),
                menuRepository: FixtureMenus(),
                adminAuthService: StaffAuth(),
                initialState: OrderFlowState(
                  person: PersonOption(
                    customerId: 'customer',
                    displayName: 'テスト',
                    openCheckId: 'visit',
                    createdAtMillis: DateTime.now().millisecondsSinceEpoch,
                    peopleCount: 2,
                    billingMode: mode,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('テスト  2名'), findsOneWidget);
        final tequilaChip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'テキーラ他'),
        );
        expect(tequilaChip.selected, isTrue);
        expect(
          tester.getTopLeft(find.text('テキーラ他')).dx,
          lessThan(tester.getTopLeft(find.text('シャンパン')).dx),
        );
        await tester.tap(find.text('フード'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('枝豆')).dx,
          lessThan(tester.getTopLeft(find.text('唐揚げ')).dx),
        );
        await tester.tap(find.text('枝豆'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('グッズ'));
        await tester.pumpAndSettle();
        expect(find.text('その他フード'), findsNothing);
        await tester.tap(find.text('Tシャツ'));
        await tester.pumpAndSettle();
        expect(find.textContaining('2点'), findsOneWidget);
        await tester.tap(find.text('ドリンク'));
        await tester.pumpAndSettle();
        expect(find.text('テスト  2名'), findsOneWidget);
        expect(find.textContaining('2点'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('商品一覧のカテゴリは閉じた状態で、展開できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MenuEditPage(
          menuRepository: FixtureMenus(),
          auth: SignedInAuth(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('一覧'));
    await tester.pumpAndSettle();
    final tiles = tester.widgetList<ExpansionTile>(find.byType(ExpansionTile));
    expect(tiles, isNotEmpty);
    expect(tiles.every((tile) => !tile.initiallyExpanded), isTrue);
    expect(find.text('唐揚げ').hitTestable(), findsNothing);
    await tester.tap(find.widgetWithText(ExpansionTile, 'フード'));
    await tester.pumpAndSettle();
    expect(find.text('唐揚げ').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
