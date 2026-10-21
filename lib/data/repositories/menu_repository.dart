import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/food_menu.dart';
import '../../core/menu_category_catalog.dart';
import '../../models/menu_item.dart';

class MenuRepository {
  MenuRepository({FirebaseFirestore? firestore, String? storeId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final String _storeId;
  CollectionReference<Map<String, dynamic>> get _menus =>
      _firestore.collection('stores').doc(_storeId).collection('menus');

  /// 管理画面用。非表示（isActive: false）も含めて全件。
  Stream<List<MenuItem>> streamAllMenus() {
    return _menus.snapshots().map((snapshot) {
      final menus = snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
          .toList();
      menus.sort((a, b) {
        final categoryCompare = MenuCategoryCatalog.compareKeys(
          a.category,
          b.category,
        );
        if (categoryCompare != 0) return categoryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return menus;
    });
  }

  /// 注文画面のドリンク用。常設フードは [streamActiveFoodMenus] で別に扱う。
  Stream<List<MenuItem>> streamActiveMenus() {
    return _menus.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final menus = snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
          .where((m) => !isRegisteredFoodMenu(m))
          .toList();
      menus.sort((a, b) {
        final categoryCompare = MenuCategoryCatalog.compareKeys(
          a.category,
          b.category,
        );
        if (categoryCompare != 0) return categoryCompare;
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return menus;
    });
  }

  Future<void> seedMenusFromAssetIfEmpty() async {
    final existing = await _menus.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final jsonText = await rootBundle.loadString('menus.seed.json');
    final List<dynamic> rows = jsonDecode(jsonText) as List<dynamic>;
    final batch = _firestore.batch();
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      final doc = _menus.doc();
      batch.set(doc, map);
    }
    await batch.commit();
  }

  /// 同カテゴリ内の最大 sortOrder の次の値で追加する。
  /// 同カテゴリに同名（休止中を含む）があれば [StateError]。
  Future<String> addMenu({
    required String name,
    required String category,
    required int priceTaxIncluded,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('メニュー名を入力してください');
    }
    if (priceTaxIncluded < 0) {
      throw ArgumentError('金額が不正です');
    }
    final inCategory = await _menus
        .where('category', isEqualTo: category)
        .get();
    final names = inCategory.docs.map((d) => d.data()['name'] as String? ?? '');
    if (hasDuplicateFoodName(names, trimmed)) {
      throw StateError('「$trimmed」はすでに登録されています');
    }
    var maxOrder = 0;
    for (final d in inCategory.docs) {
      final so = (d.data()['sortOrder'] as num?)?.toInt() ?? 0;
      if (so > maxOrder) maxOrder = so;
    }
    final ref = await _menus.add({
      'name': trimmed,
      'category': category,
      'priceTaxIncluded': priceTaxIncluded,
      'isActive': true,
      'sortOrder': maxOrder + 10,
    });
    return ref.id;
  }

  Future<void> deleteMenu(String menuId) async {
    await _menus.doc(menuId).delete();
  }

  /// 休止（注文画面から隠す）／再開。フード・ドリンク共通。
  Future<void> setMenuActive(String menuId, bool isActive) async {
    await _menus.doc(menuId).update({'isActive': isActive});
  }

  Query<Map<String, dynamic>> get _foodMenus =>
      _menus.where('category', isEqualTo: kFoodRegisteredCategory);

  /// 管理画面用。休止中（isActive: false）も含む。
  Stream<List<MenuItem>> streamAllFoodMenus() {
    return _foodMenus.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MenuItem.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  Stream<List<MenuItem>> streamActiveFoodMenus() {
    return streamAllFoodMenus().map(
      (menus) => menus.where((m) => m.isActive).toList(),
    );
  }

  /// 同名（休止中を含む）があれば [StateError]。単価変更は削除して登録し直す運用。
  Future<void> addFoodMenu({
    required String name,
    required int priceTaxIncluded,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('メニュー名を入力してください');
    }
    if (priceTaxIncluded < 0) {
      throw ArgumentError('金額が不正です');
    }
    final existing = await _foodMenus.get();
    final names = existing.docs.map((d) => d.data()['name'] as String? ?? '');
    if (hasDuplicateFoodName(names, trimmed)) {
      throw StateError('「$trimmed」はすでに登録されています');
    }
    var maxOrder = 0;
    for (final d in existing.docs) {
      final so = (d.data()['sortOrder'] as num?)?.toInt() ?? 0;
      if (so > maxOrder) maxOrder = so;
    }
    await _menus.add({
      'name': trimmed,
      'category': kFoodRegisteredCategory,
      'priceTaxIncluded': priceTaxIncluded,
      'isActive': true,
      'sortOrder': maxOrder + 10,
    });
  }

}
