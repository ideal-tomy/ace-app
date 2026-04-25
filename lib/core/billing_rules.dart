import '../models/check_item.dart';
import '../models/check_summary.dart';
import '../models/menu_item.dart';

class BillingBreakdown {
  const BillingBreakdown({
    required this.mainDrinksTotal,
    required this.separateDrinksTotal,
    required this.timeCharge,
  });

  final int mainDrinksTotal;
  final int separateDrinksTotal;
  final int timeCharge;

  int get normalTotal => mainDrinksTotal + separateDrinksTotal + timeCharge;
}

BillingBreakdown buildBillingBreakdown({
  required CheckSummary summary,
  required List<CheckItem> items,
  required DateTime now,
}) {
  var separate = 0;
  for (final item in items) {
    if (isSeparateAccountingByNameAndCategory(
      name: item.menuNameSnapshot,
      category: item.menuCategorySnapshot,
    )) {
      separate += item.lineTotalTaxIncluded;
    }
  }
  final allItemsTotal = summary.totalTaxIncluded;
  final main = (allItemsTotal - separate).clamp(0, allItemsTotal);
  final elapsed = now.difference(summary.createdAt);
  final charge = calcTimeCharge(elapsed);
  return BillingBreakdown(
    mainDrinksTotal: main,
    separateDrinksTotal: separate,
    timeCharge: charge,
  );
}

bool isSeparateAccountingMenu(MenuItem item) {
  return isSeparateAccountingByNameAndCategory(
    name: item.name,
    category: item.category,
  );
}

bool isSeparateAccountingCheckItem(CheckItem item) {
  return isSeparateAccountingByNameAndCategory(
    name: item.menuNameSnapshot,
    category: item.menuCategorySnapshot,
  );
}

bool isSeparateAccountingByNameAndCategory({
  required String name,
  required String category,
}) {
  final normalizedCategory = category.toUpperCase();
  final normalizedName = name.toLowerCase();
  // 「テキーラサンライズ」はカクテル扱いで通常会計に含める。
  if (normalizedName.contains('テキーラサンライズ')) return false;
  if (normalizedCategory == 'CHAMPAGNE') return true;
  return normalizedName.contains('テキーラ') ||
      normalizedName.contains('イエガー') ||
      normalizedName.contains('マルガリータ') ||
      normalizedName.contains('クライナー') ||
      normalizedName.contains('コカボム') ||
      normalizedName.contains('シャンパン');
}

int calcTimeCharge(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  if (minutes <= 60) return 1200;
  final extraMinutes = minutes - 60;
  final extraHalfHours = (extraMinutes / 30).ceil();
  return 1200 + (extraHalfHours * 600);
}
