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

  /// 管理者のみ全件読取可能（Firestore ルールで制限）。
  Stream<List<FinanceEntry>> streamAllExpenseEntries() {
    return _expenseEntries.orderBy('date', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => FinanceEntry.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// 自分が登録した経費のみ（スタッフ用）。
  Stream<List<FinanceEntry>> streamMyExpenseEntries() {
    final user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) {
      return Stream.value(const <FinanceEntry>[]);
    }
    return _expenseEntries
        .where('createdBy', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FinanceEntry.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> addExpenseEntry({
    required DateTime date,
    required String accountItemId,
    required String category,
    required int amount,
    String memo = '',
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('経費の登録にはログインが必要です');
    }
    final aid = accountItemId.trim();
    if (aid.isEmpty) {
      throw ArgumentError('accountItemId は空にできません');
    }
    await _expenseEntries.add({
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'accountItemId': aid,
      'category': category.trim(),
      'amount': amount,
      'memo': memo.trim(),
      'createdBy': uid,
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
