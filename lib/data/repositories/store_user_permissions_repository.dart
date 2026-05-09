import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';
import '../../models/store_user_permissions.dart';

class StoreUserPermissionsRepository {
  StoreUserPermissionsRepository({
    FirebaseFirestore? firestore,
    String? storeId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('stores').doc(_storeId).collection('users');

  Stream<List<StoreUserPermissions>> streamStoreUsers() {
    return _users.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StoreUserPermissions.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => a.uid.compareTo(b.uid));
      return list;
    });
  }

  Future<void> upsertStoreUser({
    required String uid,
    String? email,
    required List<String> moduleRoles,
  }) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) throw ArgumentError('UIDを入力してください');

    final sanitized = moduleRoles
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final data = <String, dynamic>{
      AppConfig.moduleRolesField: sanitized,
      'updatedAt': FieldValue.serverTimestamp(),
      if (email != null && email.trim().isNotEmpty)
        'email': email.trim()
      else
        'email': FieldValue.delete(),
    };
    await _users.doc(trimmedUid).set(data, SetOptions(merge: true));
  }

  Future<void> deleteStoreUser(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) return;
    await _users.doc(trimmedUid).delete();
  }
}
