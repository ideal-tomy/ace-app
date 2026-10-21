import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_config.dart';
import '../../core/billing_rules.dart';
import '../../core/business_day.dart';
import '../../core/business_mode.dart';
import '../../core/payment_method.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';

class CheckRepository {
  CheckRepository({FirebaseFirestore? firestore, Uuid? uuid, String? storeId})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _uuid = uuid ?? const Uuid(),
      _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _checks =>
      _firestore.collection('stores').doc(_storeId).collection('checks');

  Stream<List<PersonOption>> streamOpenPeople() {
    return _checks.where('status', isEqualTo: 'open').snapshots().map((
      snapshot,
    ) {
      final people = snapshot.docs.map((doc) {
        final data = doc.data();
        final billingMode = businessModeFromFirestore(
          data['billingMode'] as String?,
        );
        return PersonOption(
          customerId: (data['customerId'] as String?) ?? '',
          displayName: (data['customerNameSnapshot'] as String?) ?? '',
          openCheckId: doc.id,
          createdAtMillis:
              ((data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch) ?? 0,
          billingMode: billingMode,
          switchedFromEvent: data['switchedFromEvent'] as bool? ?? false,
          totalTaxIncluded: (data['totalTaxIncluded'] as num?)?.toInt() ?? 0,
          peopleCount: (data['peopleCount'] as num?)?.toInt() ?? 1,
          nomihodaiStartedAtMillis:
              (data['nomihodaiStartedAt'] as Timestamp?)
                  ?.millisecondsSinceEpoch,
        );
      }).toList();
      people.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
      return people;
    });
  }

  Stream<List<CheckSummary>> streamOpenChecks() {
    // status のみで取得し、複合インデックス不要。並びはクライアント側。
    return _checks.where('status', isEqualTo: 'open').snapshots().map((s) {
      final checks = s.docs
          .map((doc) => CheckSummary.fromMap(doc.id, doc.data()))
          .toList();
      checks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return checks;
    });
  }

  Stream<CheckSummary?> streamCheckSummary(String checkId) {
    return _checks.doc(checkId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CheckSummary.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<CheckItem>> streamCheckItems(String checkId) {
    return _checks
        .doc(checkId)
        .collection('items')
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CheckItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<int> countCheckItems(String checkId) async {
    final snap = await _checks.doc(checkId).collection('items').limit(1).get();
    return snap.docs.length;
  }

  /// 伝票を作成し、作成した checkId を返す。
  Future<String> createOpenCheck({
    required String customerName,
    required BusinessMode billingMode,
    required int peopleCount,
  }) async {
    final customerId = _uuid.v4();
    final data = <String, dynamic>{
      'customerId': customerId,
      'customerNameSnapshot': customerName.trim(),
      'peopleCount': peopleCount,
      'billingMode': billingMode.firestoreValue,
      'status': 'open',
      'subtotalTaxIncluded': 0,
      'taxAmount': 0,
      'totalTaxIncluded': 0,
      'createdBy': 'device',
      'createdAt': FieldValue.serverTimestamp(),
      'closedAt': null,
      'switchedFromEvent': false,
    };
    if (billingMode == BusinessMode.normal) {
      data['nomihodaiStartedAt'] = FieldValue.serverTimestamp();
    }
    final docRef = await _checks.add(data);
    return docRef.id;
  }

  Future<void> voidCheck({
    required String checkId,
    String? reason,
  }) async {
    final docRef = _checks.doc(checkId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('伝票が存在しません。');
      }
      final status = snap.data()!['status'] as String? ?? 'open';
      if (status != 'open') {
        throw StateError('未会計の伝票のみ取消できます。');
      }
      final update = <String, dynamic>{
        'status': 'voided',
        'voidedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null && reason.trim().isNotEmpty) {
        update['voidReason'] = reason.trim();
      }
      txn.update(docRef, update);
    });
  }

  Future<void> switchToNomihodai(String checkId) async {
    final docRef = _checks.doc(checkId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('伝票が存在しません。');
      }
      final data = snap.data()!;
      if ((data['status'] as String? ?? 'open') != 'open') {
        throw StateError('未会計の伝票のみ切り替えできます。');
      }
      final mode = businessModeFromFirestore(data['billingMode'] as String?);
      if (mode != BusinessMode.event) {
        throw StateError('すでに通常営業（投げ放題）です。');
      }
      txn.update(docRef, {
        'billingMode': BusinessMode.normal.firestoreValue,
        'nomihodaiStartedAt': FieldValue.serverTimestamp(),
        'switchedFromEvent': true,
      });
    });
  }

  Future<AddedOrderItem> addOrderItem({
    required String checkId,
    required MenuItem menu,
    required int qty,
  }) async {
    final docRef = _checks.doc(checkId);
    final itemRef = docRef.collection('items').doc();
    final lineTotal = menu.priceTaxIncluded * qty;

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) {
        throw StateError('伝票が存在しません。');
      }
      final data = snap.data()!;
      if ((data['status'] as String? ?? 'open') != 'open') {
        throw StateError('会計確定済みです。');
      }

      final billingMode = businessModeFromFirestore(
        data['billingMode'] as String?,
      );
      final currentTotal = (data['totalTaxIncluded'] as num?)?.toInt() ?? 0;
      final newTotal = currentTotal + lineTotal;
      final taxAmount = (newTotal * 10 / 110).floor();

      txn.set(itemRef, {
        'menuId': menu.id,
        'menuNameSnapshot': menu.name,
        'menuCategorySnapshot': menu.category,
        'unitPriceTaxIncluded': menu.priceTaxIncluded,
        'qty': qty,
        'lineTotalTaxIncluded': lineTotal,
        'orderedAt': FieldValue.serverTimestamp(),
        'billedAs': billingMode.firestoreValue,
      });

      txn.update(docRef, {
        'subtotalTaxIncluded': newTotal,
        'taxAmount': taxAmount,
        'totalTaxIncluded': newTotal,
      });
    });
    return AddedOrderItem(
      checkId: checkId,
      itemId: itemRef.id,
      menuName: menu.name,
      qty: qty,
      lineTotalTaxIncluded: lineTotal,
    );
  }

  Future<void> updateOrderItemQty({
    required String checkId,
    required CheckItem item,
    required int newQty,
  }) async {
    if (newQty <= 0) {
      throw ArgumentError.value(newQty, 'newQty', '数量は1以上にしてください');
    }
    if (newQty == item.qty) return;

    final docRef = _checks.doc(checkId);
    final itemRef = docRef.collection('items').doc(item.id);
    final newLineTotal = item.unitPriceTaxIncluded * newQty;
    final delta = newLineTotal - item.lineTotalTaxIncluded;

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) {
        throw StateError('伝票が存在しません。');
      }
      final data = snap.data()!;
      if ((data['status'] as String? ?? 'open') != 'open') {
        throw StateError('会計確定済みの伝票は明細を変更できません。');
      }

      final currentTotal = (data['totalTaxIncluded'] as num?)?.toInt() ?? 0;
      final newTotal = currentTotal + delta;
      final taxAmount = (newTotal * 10 / 110).floor();

      txn.update(itemRef, {
        'qty': newQty,
        'lineTotalTaxIncluded': newLineTotal,
      });
      txn.update(docRef, {
        'subtotalTaxIncluded': newTotal,
        'taxAmount': taxAmount,
        'totalTaxIncluded': newTotal,
      });
    });
  }

  Future<void> removeOrderItem({
    required String checkId,
    required String itemId,
    required int lineTotalTaxIncluded,
  }) async {
    final docRef = _checks.doc(checkId);
    final itemRef = docRef.collection('items').doc(itemId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) return;
      final data = snap.data()!;
      if ((data['status'] as String? ?? 'open') != 'open') {
        throw StateError('会計確定済みの伝票は明細を削除できません。');
      }
      final currentTotal = (data['totalTaxIncluded'] as num?)?.toInt() ?? 0;
      final newTotal = (currentTotal - lineTotalTaxIncluded).clamp(
        0,
        currentTotal,
      );
      final taxAmount = (newTotal * 10 / 110).floor();

      txn.delete(itemRef);
      txn.update(docRef, {
        'subtotalTaxIncluded': newTotal,
        'taxAmount': taxAmount,
        'totalTaxIncluded': newTotal,
      });
    });
  }

  Future<void> finalizeCheck(
    String checkId, {
    required PaymentMethod paymentMethod,
  }) async {
    final docRef = _checks.doc(checkId);
    final finalizedAt = DateTime.now();
    final businessDate = businessDateFor(finalizedAt);
    final itemsQuery = docRef.collection('items');
    final itemsSnap = await itemsQuery.get();
    final items = itemsSnap.docs
        .map((doc) => CheckItem.fromMap(doc.id, doc.data()))
        .toList();
    await _firestore.runTransaction((txn) async {
      final checkSnap = await txn.get(docRef);
      if (!checkSnap.exists || checkSnap.data() == null) {
        throw StateError('伝票が存在しません。');
      }
      final checkSummary = CheckSummary.fromMap(
        checkSnap.id,
        checkSnap.data()!,
      );
      if (!checkSummary.isOpen) {
        throw StateError('会計確定済みです。');
      }

      final breakdown = buildBillingBreakdown(
        summary: checkSummary,
        items: items,
        now: finalizedAt,
      );
      final merchandiseFinal = breakdown.merchandiseTotal;
      final actualStay = finalizedAt.difference(checkSummary.createdAt);

      txn.update(docRef, {
        'finalAmount': breakdown.grandTotal,
        'timeChargeFinal': breakdown.timeCharge,
        'merchandiseFinal': merchandiseFinal,
        'separateFinal': merchandiseFinal,
        'eventAmountFinal': breakdown.eventAmount,
        'normalAmountFinal': breakdown.normalAmount,
        'paymentMethod': paymentMethod.firestoreValue,
        'status': 'paid',
        'closedAt': FieldValue.serverTimestamp(),
        'businessDate': Timestamp.fromDate(businessDate),
        'businessDateKey': businessDateKey(businessDate),
        'departedAt': Timestamp.fromDate(finalizedAt),
        'actualStayMinutesFinal': actualStay.isNegative
            ? 0
            : actualStay.inMinutes,
        'billingBilledMinutesFinal': breakdown.billedMinutesOverride,
        'timeChargeAutoFinal': breakdown.timeChargeAuto,
        'timeChargeAdjustmentAmount': breakdown.timeChargeAdjustment,
      });
    });
  }

  /// 会計対象時間（分）を指定する。null で自動計算に戻す。未会計の伝票のみ。
  Future<void> updateBillingBilledMinutes(String checkId, int? minutes) async {
    final docRef = _checks.doc(checkId);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('伝票が存在しません。');
      }
      if ((snap.data()!['status'] as String? ?? 'open') != 'open') {
        throw StateError('会計確定済みの伝票は変更できません。');
      }
      txn.update(docRef, {'billingBilledMinutes': minutes});
    });
  }

  /// 会計済み伝票の退店時刻を訂正する。確定金額・会計対象時間は変更しない。
  Future<void> updateDepartedAt({
    required String checkId,
    required DateTime departedAt,
    required String correctedBy,
  }) async {
    final docRef = _checks.doc(checkId);
    final correctionRef = docRef.collection('visit_corrections').doc();
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists || snap.data() == null) {
        throw StateError('伝票が存在しません。');
      }
      final summary = CheckSummary.fromMap(snap.id, snap.data()!);
      if (!summary.isPaid) {
        throw StateError('会計済みの伝票のみ退店時刻を修正できます。');
      }
      if (departedAt.isBefore(summary.createdAt)) {
        throw StateError('退店時刻は入店時刻より後にしてください。');
      }
      if (departedAt.isAfter(DateTime.now())) {
        throw StateError('未来の時刻は指定できません。');
      }
      txn.update(docRef, {'departedAt': Timestamp.fromDate(departedAt)});
      txn.set(correctionRef, {
        'type': 'departed_at',
        'fromAt': summary.departedAt == null
            ? null
            : Timestamp.fromDate(summary.departedAt!),
        'toAt': Timestamp.fromDate(departedAt),
        'correctedAt': FieldValue.serverTimestamp(),
        'correctedBy': correctedBy,
      });
    });
  }

  Stream<List<VisitCorrection>> streamVisitCorrections(String checkId) {
    return _checks
        .doc(checkId)
        .collection('visit_corrections')
        .orderBy('correctedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => VisitCorrection.fromMap(d.data())).toList(),
        );
  }
}

class VisitCorrection {
  const VisitCorrection({
    required this.fromAt,
    required this.toAt,
    required this.correctedAt,
  });

  final DateTime? fromAt;
  final DateTime toAt;
  final DateTime? correctedAt;

  factory VisitCorrection.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(Object? v) => v is Timestamp ? v.toDate() : null;
    return VisitCorrection(
      fromAt: toDate(map['fromAt']),
      toAt: toDate(map['toAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      correctedAt: toDate(map['correctedAt']),
    );
  }
}

class AddedOrderItem {
  const AddedOrderItem({
    required this.checkId,
    required this.itemId,
    required this.menuName,
    required this.qty,
    required this.lineTotalTaxIncluded,
  });

  final String checkId;
  final String itemId;
  final String menuName;
  final int qty;
  final int lineTotalTaxIncluded;
}
