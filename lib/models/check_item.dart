import 'package:cloud_firestore/cloud_firestore.dart';

class CheckItem {
  const CheckItem({
    required this.id,
    required this.menuNameSnapshot,
    required this.menuCategorySnapshot,
    required this.unitPriceTaxIncluded,
    required this.qty,
    required this.lineTotalTaxIncluded,
    required this.orderedAt,
  });

  final String id;
  final String menuNameSnapshot;
  final String menuCategorySnapshot;
  final int unitPriceTaxIncluded;
  final int qty;
  final int lineTotalTaxIncluded;
  final DateTime orderedAt;

  factory CheckItem.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['orderedAt'];
    return CheckItem(
      id: id,
      menuNameSnapshot: map['menuNameSnapshot'] as String? ?? '',
      menuCategorySnapshot: map['menuCategorySnapshot'] as String? ?? '',
      unitPriceTaxIncluded: (map['unitPriceTaxIncluded'] as num?)?.toInt() ?? 0,
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      lineTotalTaxIncluded: (map['lineTotalTaxIncluded'] as num?)?.toInt() ?? 0,
      orderedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
