import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceEntry {
  const FinanceEntry({
    required this.id,
    required this.date,
    required this.category,
    this.accountItemId,
    required this.amount,
    required this.memo,
    required this.createdBy,
    required this.updatedAt,
  });

  final String id;
  final DateTime date;
  final String category;

  /// 経費マスタの安定ID。旧ドキュメントでは null。
  final String? accountItemId;
  final int amount;
  final String memo;
  final String createdBy;
  final DateTime updatedAt;

  factory FinanceEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawAid = map['accountItemId'];
    String? accountItemId;
    if (rawAid is String) {
      final t = rawAid.trim();
      if (t.isNotEmpty) accountItemId = t;
    }
    return FinanceEntry(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: (map['category'] as String?) ?? '',
      accountItemId: accountItemId,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      memo: (map['memo'] as String?) ?? '',
      createdBy: (map['createdBy'] as String?) ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
