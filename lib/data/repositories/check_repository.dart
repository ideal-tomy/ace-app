import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_config.dart';
import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';

class CheckRepository {
  CheckRepository({
    FirebaseFirestore? firestore,
    Uuid? uuid,
    String? storeId,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid(),
        _storeId = storeId ?? AppConfig.storeId;

  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  final String _storeId;

  CollectionReference<Map<String, dynamic>> get _checks =>
      _firestore.collection('stores').doc(_storeId).collection('checks');

  Stream<List<PersonOption>> streamOpenPeople() {
    return _checks
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map(
          (snapshot) {
            final people = snapshot.docs
              .map((doc) => PersonOption(
                    customerId: (doc.data()['customerId'] as String?) ?? '',
                    displayName:
                        (doc.data()['customerNameSnapshot'] as String?) ?? '',
                    openCheckId: doc.id,
                    createdAtMillis:
                        ((doc.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch) ?? 0,
                  ))
              .toList();
            people.sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
            return people;
          },
        );
  }

  Stream<List<CheckSummary>> streamOpenChecks() {
    return _checks
        .where('status', isEqualTo: 'open')
        .orderBy('customerNameSnapshot')
        .snapshots()
        .map((s) => s.docs.map((doc) => CheckSummary.fromMap(doc.id, doc.data())).toList());
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
          (snapshot) =>
              snapshot.docs.map((doc) => CheckItem.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<void> createOpenCheck({
    required String customerName,
    required BusinessMode billingMode,
  }) async {
    final customerId = _uuid.v4();
    await _checks.add({
      'customerId': customerId,
      'customerNameSnapshot': customerName.trim(),
      'billingMode': billingMode.firestoreValue,
      'status': 'open',
      'subtotalTaxIncluded': 0,
      'taxAmount': 0,
      'totalTaxIncluded': 0,
      'createdBy': 'device',
      'createdAt': FieldValue.serverTimestamp(),
      'closedAt': null,
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
      final newTotal = (currentTotal - lineTotalTaxIncluded).clamp(0, currentTotal);
      final taxAmount = (newTotal * 10 / 110).floor();

      txn.delete(itemRef);
      txn.update(docRef, {
        'subtotalTaxIncluded': newTotal,
        'taxAmount': taxAmount,
        'totalTaxIncluded': newTotal,
      });
    });
  }

  Future<void> finalizeCheck(String checkId) async {
    final docRef = _checks.doc(checkId);
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
      final checkSummary = CheckSummary.fromMap(checkSnap.id, checkSnap.data()!);
      if (!checkSummary.isOpen) {
        throw StateError('会計確定済みです。');
      }

      var finalAmount = checkSummary.totalTaxIncluded;
      var timeChargeFinal = 0;
      var separateFinal = 0;
      if (checkSummary.billingMode == BusinessMode.normal) {
        final breakdown = buildBillingBreakdown(
          summary: checkSummary,
          items: items,
          now: DateTime.now(),
        );
        finalAmount = breakdown.normalTotal;
        timeChargeFinal = breakdown.timeCharge;
        separateFinal = breakdown.separateDrinksTotal;
      }

      txn.update(docRef, {
        'finalAmount': finalAmount,
        'timeChargeFinal': timeChargeFinal,
        'separateFinal': separateFinal,
        'status': 'paid',
        'closedAt': FieldValue.serverTimestamp(),
      });
    });
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
