import 'package:cloud_firestore/cloud_firestore.dart';

class CheckSummary {
  const CheckSummary({
    required this.id,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.status,
    required this.totalTaxIncluded,
    required this.taxAmount,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String customerNameSnapshot;
  final String status;
  final int totalTaxIncluded;
  final int taxAmount;
  final DateTime createdAt;

  bool get isOpen => status == 'open';

  factory CheckSummary.fromMap(String id, Map<String, dynamic> map) {
    return CheckSummary(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerNameSnapshot: map['customerNameSnapshot'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      totalTaxIncluded: (map['totalTaxIncluded'] as num?)?.toInt() ?? 0,
      taxAmount: (map['taxAmount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as dynamic) is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
