// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ace_app/app.dart';

void main() {
  testWidgets('初期化エラー時はエラー画面を表示', (WidgetTester tester) async {
    await tester.pumpWidget(const AceApp(initializationError: 'err'));
    expect(find.textContaining('Firebase初期化に失敗しました'), findsOneWidget);
  });
}
