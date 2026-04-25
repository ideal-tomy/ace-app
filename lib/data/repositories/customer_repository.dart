import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_config.dart';

class CustomerRepository {
  CustomerRepository({FirebaseFirestore? firestore, String? storeId})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('stores').doc(_storeId).collection('customers');

  Future<void> createCustomerIfNeeded(String displayName) async {
    final cleaned = displayName.trim();
    if (cleaned.isEmpty) return;
    final query = await _customers
        .where('displayName', isEqualTo: cleaned)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) return;
    await _customers.add({
      'displayName': cleaned,
      'aliases': [cleaned],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> streamCustomerNames() {
    return _customers.orderBy('displayName').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => (doc.data()['displayName'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList(),
    );
  }
}
