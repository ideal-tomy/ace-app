import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../../core/menu_admin_family_order.dart';

class StoreSettingsRepository {
  StoreSettingsRepository({FirebaseFirestore? firestore, String? storeId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final String _storeId;

  DocumentReference<Map<String, dynamic>> get _storeRef =>
      _firestore.collection('stores').doc(_storeId);

  /// 未設定の店舗は `null`（注文画面は従来の並び順）。
  Stream<List<String>?> streamDrinkFamilyOrderKeys() {
    return _storeRef.snapshots().map((snap) {
      final raw = snap.data()?[kAdminMenuFamilyOrderField];
      if (raw is! List) return null;
      return resolveDrinkFamilyOrderKeys(
        raw.map((e) => e.toString()).toList(),
      );
    });
  }

  Future<void> saveDrinkFamilyOrderKeys(List<String> keys) async {
    await _storeRef.set({
      kAdminMenuFamilyOrderField: resolveDrinkFamilyOrderKeys(keys),
    }, SetOptions(merge: true));
  }
}
