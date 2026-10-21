import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_config.dart';
import '../../core/business_day.dart';
import '../../core/business_mode.dart';
import '../../core/payment_method.dart';
import '../../models/check_summary.dart';
import '../../models/daily_closing.dart';

class SalesSummaryRepository {
  SalesSummaryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String? storeId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _checks =>
      _firestore.collection('stores').doc(_storeId).collection('checks');

  CollectionReference<Map<String, dynamic>> get _dailyClosings => _firestore
      .collection('stores')
      .doc(_storeId)
      .collection('daily_closings');

  Stream<List<CheckSummary>> streamAllChecks() {
    return _checks.snapshots().map((snapshot) {
      final rows = snapshot.docs
          .map((doc) => CheckSummary.fromMap(doc.id, doc.data()))
          .toList();
      rows.sort((a, b) {
        final aTime = a.closedAt ?? a.createdAt;
        final bTime = b.closedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      return rows;
    });
  }

  Stream<DailyClosing?> streamDailyClosing(String businessDateKey) {
    return _dailyClosings.doc(businessDateKey).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return DailyClosing.fromMap(snapshot.id, data);
    });
  }

  Stream<List<DailyClosingCheck>> streamClosingChecks(String businessDateKey) {
    return _dailyClosings
        .doc(businessDateKey)
        .collection('checks')
        .orderBy('closedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DailyClosingCheck.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  DateTime effectiveBusinessDate(CheckSummary check) {
    return check.businessDate ??
        businessDateFor(check.closedAt ?? check.createdAt);
  }

  /// 伝票のイベント按分額（確定値があれば優先、なければ最終モードで全額）。
  int eventAmountOf(CheckSummary check) {
    if (check.eventAmountFinal != null) return check.eventAmountFinal!;
    final total = check.finalAmount ?? check.totalTaxIncluded;
    if (check.billingMode == BusinessMode.event && !check.switchedFromEvent) {
      return total;
    }
    return 0;
  }

  /// 伝票の通常按分額。
  int normalAmountOf(CheckSummary check) {
    if (check.normalAmountFinal != null) return check.normalAmountFinal!;
    final total = check.finalAmount ?? check.totalTaxIncluded;
    if (check.billingMode == BusinessMode.normal) return total;
    return 0;
  }

  int amountOf(CheckSummary check) =>
      check.finalAmount ?? check.totalTaxIncluded;

  Future<void> closeBusinessDay({
    required DateTime businessDate,
    required List<CheckSummary> paidChecks,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('日次締めにはログインが必要です');
    if (paidChecks.length > 450) {
      throw StateError('一度に締められる会計は450件までです');
    }

    final key = businessDateKey(businessDate);
    final closingRef = _dailyClosings.doc(key);
    // 件数・人数は最終モードで分類（切替伝票は通常側）。
    final eventChecks = paidChecks
        .where((check) => check.billingMode == BusinessMode.event)
        .toList();
    final normalChecks = paidChecks
        .where((check) => check.billingMode == BusinessMode.normal)
        .toList();
    // 金額は按分フィールドで集計。
    final eventSales = paidChecks.fold(0, (sum, c) => sum + eventAmountOf(c));
    final normalSales = paidChecks.fold(0, (sum, c) => sum + normalAmountOf(c));
    int guestsOf(List<CheckSummary> rows) =>
        rows.fold(0, (sum, check) => sum + check.peopleCount);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(closingRef);
      if (existing.exists) throw StateError('$key はすでに日次締め済みです');

      transaction.set(closingRef, {
        'businessDate': Timestamp.fromDate(businessDate),
        'businessDateKey': key,
        'status': 'closed',
        'totalSales': eventSales + normalSales,
        'eventSales': eventSales,
        'normalSales': normalSales,
        'checkCount': paidChecks.length,
        'eventCheckCount': eventChecks.length,
        'normalCheckCount': normalChecks.length,
        'guestCount': guestsOf(paidChecks),
        'eventGuestCount': guestsOf(eventChecks),
        'normalGuestCount': guestsOf(normalChecks),
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': user.uid,
        'schemaVersion': 1,
      });

      for (final check in paidChecks) {
        final closedAt = check.closedAt;
        if (closedAt == null) {
          throw StateError('${check.customerNameSnapshot} の会計時刻がありません');
        }
        final payment =
            check.paymentMethod ?? PaymentMethod.other;
        final eventAmt = eventAmountOf(check);
        final normalAmt = normalAmountOf(check);
        transaction.set(closingRef.collection('checks').doc(check.id), {
          'businessDateKey': key,
          'checkId': check.id,
          'customerName': check.customerNameSnapshot,
          'billingMode': check.billingMode.firestoreValue,
          'peopleCount': check.peopleCount,
          'finalAmount': amountOf(check),
          'taxAmount': check.taxAmount,
          'closedAt': Timestamp.fromDate(closedAt),
          'paymentMethod': payment.firestoreValue,
          'eventAmount': eventAmt,
          'normalAmount': normalAmt,
        });
      }
    });
  }
}
