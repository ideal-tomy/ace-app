import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_config.dart';
import '../../models/finance_entry.dart';

class FinanceEntryRepository {
  FinanceEntryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? storeId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _accountingEntries => _firestore
      .collection('stores')
      .doc(_storeId)
      .collection('accounting_entries');

  CollectionReference<Map<String, dynamic>> get _expenseEntries => _firestore
      .collection('stores')
      .doc(_storeId)
      .collection('expense_entries');

  Stream<List<FinanceEntry>> streamExpenseEntries() {
    return _expenseEntries.orderBy('date', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => FinanceEntry.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> addExpenseEntry({
    required DateTime date,
    required String category,
    required int amount,
    String memo = '',
  }) async {
    final user = _auth.currentUser;
    await _expenseEntries.add({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'category': category.trim(),
      'amount': amount,
      'memo': memo.trim(),
      'createdBy': user?.uid ?? 'unknown',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addAccountingEntry({
    required DateTime date,
    required String category,
    required int amount,
    String memo = '',
  }) async {
    final user = _auth.currentUser;
    await _accountingEntries.add({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'category': category.trim(),
      'amount': amount,
      'memo': memo.trim(),
      'createdBy': user?.uid ?? 'unknown',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
