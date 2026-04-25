import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/business_mode.dart';

class CheckSummary {
  const CheckSummary({
    required this.id,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.billingMode,
    required this.status,
    required this.totalTaxIncluded,
    required this.taxAmount,
    required this.createdAt,
    this.finalAmount,
    this.timeChargeFinal,
    this.separateFinal,
  });

  final String id;
  final String customerId;
  final String customerNameSnapshot;
  final BusinessMode billingMode;
  final String status;
  final int totalTaxIncluded;
  final int taxAmount;
  final DateTime createdAt;
  final int? finalAmount;
  final int? timeChargeFinal;
  final int? separateFinal;

  bool get isOpen => status == 'open';

  factory CheckSummary.fromMap(String id, Map<String, dynamic> map) {
    return CheckSummary(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerNameSnapshot: map['customerNameSnapshot'] as String? ?? '',
      billingMode: businessModeFromFirestore(map['billingMode'] as String?),
      status: map['status'] as String? ?? 'open',
      totalTaxIncluded: (map['totalTaxIncluded'] as num?)?.toInt() ?? 0,
      taxAmount: (map['taxAmount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as dynamic) is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      finalAmount: (map['finalAmount'] as num?)?.toInt(),
      timeChargeFinal: (map['timeChargeFinal'] as num?)?.toInt(),
      separateFinal: (map['separateFinal'] as num?)?.toInt(),
    );
  }
}
