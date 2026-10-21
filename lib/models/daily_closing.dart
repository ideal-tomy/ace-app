import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/business_mode.dart';
import '../core/payment_method.dart';

class DailyClosing {
  const DailyClosing({
    required this.id,
    required this.businessDate,
    required this.businessDateKey,
    required this.totalSales,
    required this.eventSales,
    required this.normalSales,
    required this.checkCount,
    required this.eventCheckCount,
    required this.normalCheckCount,
    required this.guestCount,
    required this.eventGuestCount,
    required this.normalGuestCount,
    required this.closedAt,
    required this.closedBy,
  });

  final String id;
  final DateTime businessDate;
  final String businessDateKey;
  final int totalSales;
  final int eventSales;
  final int normalSales;
  final int checkCount;
  final int eventCheckCount;
  final int normalCheckCount;
  final int guestCount;
  final int eventGuestCount;
  final int normalGuestCount;
  final DateTime? closedAt;
  final String closedBy;

  factory DailyClosing.fromMap(String id, Map<String, dynamic> map) {
    return DailyClosing(
      id: id,
      businessDate: (map['businessDate'] as Timestamp).toDate(),
      businessDateKey: map['businessDateKey'] as String,
      totalSales: (map['totalSales'] as num).toInt(),
      eventSales: (map['eventSales'] as num).toInt(),
      normalSales: (map['normalSales'] as num).toInt(),
      checkCount: (map['checkCount'] as num).toInt(),
      eventCheckCount: (map['eventCheckCount'] as num).toInt(),
      normalCheckCount: (map['normalCheckCount'] as num).toInt(),
      guestCount: (map['guestCount'] as num).toInt(),
      eventGuestCount: (map['eventGuestCount'] as num).toInt(),
      normalGuestCount: (map['normalGuestCount'] as num).toInt(),
      closedAt: map['closedAt'] is Timestamp
          ? (map['closedAt'] as Timestamp).toDate()
          : null,
      closedBy: map['closedBy'] as String,
    );
  }
}

class DailyClosingCheck {
  const DailyClosingCheck({
    required this.id,
    required this.businessDateKey,
    required this.customerName,
    required this.billingMode,
    required this.peopleCount,
    required this.finalAmount,
    required this.taxAmount,
    required this.closedAt,
    this.paymentMethod,
    this.eventAmount,
    this.normalAmount,
  });

  final String id;
  final String businessDateKey;
  final String customerName;
  final BusinessMode billingMode;
  final int peopleCount;
  final int finalAmount;
  final int taxAmount;
  final DateTime closedAt;
  final PaymentMethod? paymentMethod;
  final int? eventAmount;
  final int? normalAmount;

  factory DailyClosingCheck.fromMap(String id, Map<String, dynamic> map) {
    return DailyClosingCheck(
      id: id,
      businessDateKey: map['businessDateKey'] as String,
      customerName: map['customerName'] as String,
      billingMode: businessModeFromFirestore(map['billingMode'] as String?),
      peopleCount: (map['peopleCount'] as num).toInt(),
      finalAmount: (map['finalAmount'] as num).toInt(),
      taxAmount: (map['taxAmount'] as num).toInt(),
      closedAt: (map['closedAt'] as Timestamp).toDate(),
      paymentMethod: paymentMethodFromFirestore(map['paymentMethod'] as String?),
      eventAmount: (map['eventAmount'] as num?)?.toInt(),
      normalAmount: (map['normalAmount'] as num?)?.toInt(),
    );
  }
}
