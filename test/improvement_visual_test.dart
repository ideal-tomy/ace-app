import 'dart:io';
import 'dart:ui' as ui;

import 'package:ace_app/core/billing_rules.dart';
import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/data/repositories/check_repository.dart';
import 'package:ace_app/features/admin/menu_edit_page.dart';
import 'package:ace_app/features/checkout/time_adjust_card.dart';
import 'package:ace_app/features/home/home_page.dart';
import 'package:ace_app/features/order/order_flow_sheet.dart';
import 'package:ace_app/features/order/order_flow_state.dart';
import 'package:ace_app/models/person_option.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/improvement_fixtures.dart';
import 'support/memory_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('C:/Windows/Fonts/meiryo.ttc');
  setUpAll(() async {
    final icons = File(
      'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(await icons.readAsBytes())),
          ))
          .load();
    }
    if (font.existsSync()) {
      final loader = FontLoader('Meiryo')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });

  testWidgets('スマホ幅で日本語フォントを使って画面を描画する', (tester) async {
    final key = GlobalKey();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> show(Widget widget) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Meiryo',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFEA580C),
              ),
            ),
            home: widget,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/improvement-verification-2026-10-21/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    final store = MemoryFirestore();
    store.documents['stores/test/checks/visit'] = {
      'customerNameSnapshot': 'テスト',
      'peopleCount': 2,
      'status': 'open',
      'billingMode': 'normal',
      'totalTaxIncluded': 1200,
      'createdAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 67)),
      ),
    };
    final checks = CheckRepository(firestore: store, storeId: 'test');
    await show(
      HomePage(checkRepository: checks, adminAuthService: StaffAuth()),
    );
    await capture('home-320');
    await show(
      Scaffold(
        body: OrderFlowSheet(
          checkRepository: checks,
          menuRepository: FixtureMenus(),
          adminAuthService: StaffAuth(),
          initialState: OrderFlowState(
            person: PersonOption(
              customerId: 'test',
              displayName: 'テスト',
                peopleCount: 2,
                billingMode: BusinessMode.normal,
              openCheckId: 'visit',
              createdAtMillis: DateTime.now().millisecondsSinceEpoch,
            ),
          ),
        ),
      ),
    );
    await capture('order-drink-320');
    await tester.tap(find.text('フード'));
    await tester.pumpAndSettle();
    await capture('order-food-320');
    await tester.tap(find.text('グッズ'));
    await tester.pumpAndSettle();
    await capture('order-goods-320');
    await show(
      MenuEditPage(menuRepository: FixtureMenus(), auth: SignedInAuth()),
    );
    await capture('menu-register-320');
    await tester.tap(find.text('一覧'));
    await tester.pumpAndSettle();
    await capture('menu-list-320');
    final summary = fixtureCheck('テスト', BusinessMode.normal);
    final breakdown = buildBillingBreakdown(
      summary: summary,
      items: [],
      now: DateTime.now(),
    );
    await show(
      Scaffold(
        body: SafeArea(
          child: TimeAdjustCard(
            summary: summary,
            breakdown: breakdown,
            currency: NumberFormat.currency(
              locale: 'ja_JP',
              symbol: '¥',
              decimalDigits: 0,
            ),
            enabled: true,
            onChanged: (_) async {},
          ),
        ),
      ),
    );
    await capture('time-adjust-320');
    await tester.pumpWidget(const SizedBox());
  });
}
