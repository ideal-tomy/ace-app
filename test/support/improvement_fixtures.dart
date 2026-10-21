import 'package:ace_app/core/admin_auth_service.dart';
import 'package:ace_app/core/business_mode.dart';
import 'package:ace_app/data/repositories/menu_repository.dart';
import 'package:ace_app/models/check_summary.dart';
import 'package:ace_app/models/menu_item.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'memory_firestore.dart';

class StaffAuth implements AdminAuthService {
  @override
  Future<bool> canAccessAccounting() async => true;

  @override
  Future<bool> canPostExpense() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SignedInAuth implements FirebaseAuth {
  @override
  User? get currentUser => _Staff();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Staff implements User {
  @override
  String get uid => 'staff';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MenuItem menu(String id, String name, String category, int price) => MenuItem(
  id: id,
  name: name,
  category: category,
  priceTaxIncluded: price,
  isActive: true,
  sortOrder: 10,
);

class FixtureMenus extends MenuRepository {
  FixtureMenus() : super(firestore: MemoryFirestore(), storeId: 'fixture');
  final all = [
    menu('champagne', 'シャンパンA', 'CHAMPAGNE', 10000),
    menu('tequila', 'テキーラA', 'TEQUILA', 600),
    menu('food900', '唐揚げ', 'FOOD', 900),
    menu('food300', '枝豆', 'FOOD', 300),
    menu('goods', 'Tシャツ', 'DARTS_GOODS', 2000),
  ];
  @override
  Stream<List<MenuItem>> streamAllMenus() => Stream.value(all);
  @override
  Stream<List<MenuItem>> streamActiveMenus() => Stream.value(
    all
        .where((m) => m.category == 'CHAMPAGNE' || m.category == 'TEQUILA')
        .toList(),
  );
  @override
  Stream<List<MenuItem>> streamActiveFoodMenus() => Stream.value(
    all.where((m) => m.category == 'FOOD').toList()
      ..sort((a, b) => a.priceTaxIncluded.compareTo(b.priceTaxIncluded)),
  );
  @override
  Stream<List<MenuItem>> streamActiveGoodsMenus() =>
      Stream.value(all.where((m) => m.category == 'DARTS_GOODS').toList());
}

CheckSummary fixtureCheck(String name, BusinessMode mode, {int people = 1}) =>
    CheckSummary(
      id: name,
      customerId: name,
      customerNameSnapshot: name,
      peopleCount: people,
      billingMode: mode,
      status: 'open',
      totalTaxIncluded: 0,
      taxAmount: 0,
      createdAt: DateTime.now().subtract(const Duration(minutes: 67)),
    );
