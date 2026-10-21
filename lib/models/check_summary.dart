import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/business_mode.dart';
import '../core/payment_method.dart';

class CheckSummary {
  const CheckSummary({
    required this.id,
    required this.customerId,
    required this.customerNameSnapshot,
    required this.peopleCount,
    required this.billingMode,
    required this.status,
    required this.totalTaxIncluded,
    required this.taxAmount,
    required this.createdAt,
    this.closedAt,
    this.businessDate,
    this.finalAmount,
    this.timeChargeFinal,
    this.separateFinal,
    this.merchandiseFinal,
    this.nomihodaiStartedAt,
    this.switchedFromEvent = false,
    this.eventAmountFinal,
    this.normalAmountFinal,
    this.paymentMethod,
    this.voidedAt,
    this.voidReason,
    this.departedAt,
    this.billingBilledMinutes,
    this.billingBilledMinutesFinal,
    this.billingAutoBilledMinutesFinal,
    this.timeChargeAutoFinal,
    this.timeChargeAdjustmentAmount,
    this.actualStayMinutesFinal,
  });

  final String id;
  final String customerId;
  final String customerNameSnapshot;
  final int peopleCount;
  final BusinessMode billingMode;
  final String status;
  final int totalTaxIncluded;
  final int taxAmount;
  final DateTime createdAt;
  final DateTime? closedAt;
  final DateTime? businessDate;
  final int? finalAmount;
  final int? timeChargeFinal;
  final int? separateFinal;
  final int? merchandiseFinal;
  final DateTime? nomihodaiStartedAt;
  final bool switchedFromEvent;
  final int? eventAmountFinal;
  final int? normalAmountFinal;
  final PaymentMethod? paymentMethod;
  final DateTime? voidedAt;
  final String? voidReason;

  /// 実際の退店時刻（滞在実績の終点）。会計確定時に記録し、事後修正できる。
  final DateTime? departedAt;

  /// 会計対象時間（分）の手動指定。null は自動計算。
  final int? billingBilledMinutes;
  final int? billingBilledMinutesFinal;
  final int? billingAutoBilledMinutesFinal;

  /// 手動調整前の時間料金（全員分）。
  final int? timeChargeAutoFinal;

  /// 自動 − 確定。正は減額、負は増額。過去データの符号を維持する。
  final int? timeChargeAdjustmentAmount;

  /// 会計確定時点の実滞在（分）。
  final int? actualStayMinutesFinal;

  bool get isOpen => status == 'open';
  bool get isVoided => status == 'voided';
  bool get isPaid => status == 'paid';

  /// 時間料金の起算時刻。通常営業（または切替後）のみ有効。
  DateTime? get effectiveNomihodaiStartedAt {
    if (billingMode != BusinessMode.normal) return null;
    return nomihodaiStartedAt ?? createdAt;
  }

  String get modeBadgeLabel {
    if (switchedFromEvent && billingMode == BusinessMode.normal) {
      return 'イベント→通常';
    }
    return billingMode.label;
  }

  factory CheckSummary.fromMap(String id, Map<String, dynamic> map) {
    return CheckSummary(
      id: id,
      customerId: map['customerId'] as String? ?? '',
      customerNameSnapshot: map['customerNameSnapshot'] as String? ?? '',
      peopleCount: (map['peopleCount'] as num?)?.toInt() ?? 1,
      billingMode: businessModeFromFirestore(map['billingMode'] as String?),
      status: map['status'] as String? ?? 'open',
      totalTaxIncluded: (map['totalTaxIncluded'] as num?)?.toInt() ?? 0,
      taxAmount: (map['taxAmount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as dynamic) is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      closedAt: map['closedAt'] is Timestamp
          ? (map['closedAt'] as Timestamp).toDate()
          : null,
      businessDate: map['businessDate'] is Timestamp
          ? (map['businessDate'] as Timestamp).toDate()
          : null,
      finalAmount: (map['finalAmount'] as num?)?.toInt(),
      timeChargeFinal: (map['timeChargeFinal'] as num?)?.toInt(),
      separateFinal: (map['separateFinal'] as num?)?.toInt(),
      merchandiseFinal: (map['merchandiseFinal'] as num?)?.toInt(),
      nomihodaiStartedAt: map['nomihodaiStartedAt'] is Timestamp
          ? (map['nomihodaiStartedAt'] as Timestamp).toDate()
          : null,
      switchedFromEvent: map['switchedFromEvent'] as bool? ?? false,
      eventAmountFinal: (map['eventAmountFinal'] as num?)?.toInt(),
      normalAmountFinal: (map['normalAmountFinal'] as num?)?.toInt(),
      paymentMethod: paymentMethodFromFirestore(
        map['paymentMethod'] as String?,
      ),
      voidedAt: map['voidedAt'] is Timestamp
          ? (map['voidedAt'] as Timestamp).toDate()
          : null,
      voidReason: map['voidReason'] as String?,
      departedAt: map['departedAt'] is Timestamp
          ? (map['departedAt'] as Timestamp).toDate()
          : null,
      billingBilledMinutes: (map['billingBilledMinutes'] as num?)?.toInt(),
      billingBilledMinutesFinal: (map['billingBilledMinutesFinal'] as num?)
          ?.toInt(),
      billingAutoBilledMinutesFinal:
          (map['billingAutoBilledMinutesFinal'] as num?)?.toInt(),
      timeChargeAutoFinal: (map['timeChargeAutoFinal'] as num?)?.toInt(),
      timeChargeAdjustmentAmount: (map['timeChargeAdjustmentAmount'] as num?)
          ?.toInt(),
      actualStayMinutesFinal: (map['actualStayMinutesFinal'] as num?)?.toInt(),
    );
  }
}
