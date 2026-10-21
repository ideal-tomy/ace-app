import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/business_mode.dart';

class CheckItem {
  const CheckItem({
    required this.id,
    required this.menuNameSnapshot,
    required this.menuCategorySnapshot,
    required this.unitPriceTaxIncluded,
    required this.qty,
    required this.lineTotalTaxIncluded,
    required this.orderedAt,
    this.billedAs,
  });

  final String id;
  final String menuNameSnapshot;
  final String menuCategorySnapshot;
  final int unitPriceTaxIncluded;
  final int qty;
  final int lineTotalTaxIncluded;
  final DateTime orderedAt;
  final BusinessMode? billedAs;

  /// 明細の課金区分。未保存の旧明細は [nomihodaiStartedAt] から推定する。
  BusinessMode effectiveBilledAs({DateTime? nomihodaiStartedAt}) {
    if (billedAs != null) return billedAs!;
    if (nomihodaiStartedAt != null &&
        !orderedAt.isBefore(nomihodaiStartedAt)) {
      return BusinessMode.normal;
    }
    // 切替前、または通常営業開始前の注文はイベント扱い。
    // 通常のみの伝票で billedAs が無い旧データは呼び出し側で補完する。
    return BusinessMode.event;
  }

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
      billedAs: map['billedAs'] == null
          ? null
          : businessModeFromFirestore(map['billedAs'] as String?),
    );
  }
}
