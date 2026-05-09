import 'business_mode.dart';
import '../models/check_item.dart';
import '../models/check_summary.dart';
import '../models/menu_item.dart';

class BillingBreakdown {
  const BillingBreakdown({
    required this.foodAndBeverageTotal,
    required this.merchandiseTotal,
    required this.timeCharge,
    required this.timeChargePerPerson,
    required this.peopleCount,
  });

  final int foodAndBeverageTotal;
  final int merchandiseTotal;
  final int timeCharge;
  final int timeChargePerPerson;
  final int peopleCount;

  int get normalTotal => foodAndBeverageTotal + merchandiseTotal;

  // Backward-compatible aliases for existing UI references.
  int get mainDrinksTotal => foodAndBeverageTotal;
  int get separateDrinksTotal => merchandiseTotal;
}

BillingBreakdown buildBillingBreakdown({
  required CheckSummary summary,
  required List<CheckItem> items,
  required DateTime now,
}) {
  var merchandise = 0;
  for (final item in items) {
    if (isMerchandiseByNameAndCategory(
      name: item.menuNameSnapshot,
      category: item.menuCategorySnapshot,
    )) {
      merchandise += item.lineTotalTaxIncluded;
    }
  }
  final allItemsTotal = summary.totalTaxIncluded;
  final foodBase = (allItemsTotal - merchandise).clamp(0, allItemsTotal);
  final peopleCount = summary.peopleCount <= 0 ? 1 : summary.peopleCount;
  final isNormal = summary.billingMode == BusinessMode.normal;
  final elapsed = now.difference(summary.createdAt);
  final chargePerPerson = isNormal ? calcTimeCharge(elapsed) : 0;
  final charge = chargePerPerson * peopleCount;
  final foodWithTimeCharge = foodBase + charge;
  return BillingBreakdown(
    foodAndBeverageTotal: foodWithTimeCharge,
    merchandiseTotal: merchandise,
    timeCharge: charge,
    timeChargePerPerson: chargePerPerson,
    peopleCount: peopleCount,
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

bool isMerchandiseByNameAndCategory({
  required String name,
  required String category,
}) {
  final normalizedCategory = category.toUpperCase();
  final normalizedName = name.toLowerCase();
  if (isMerchandiseCategory(normalizedCategory)) return true;
  return normalizedName.contains('ダーツグッズ') ||
      normalizedName.contains('バレル') ||
      normalizedName.contains('フライト') ||
      normalizedName.contains('シャフト') ||
      normalizedName.contains('チップ');
}

bool isMerchandiseCategory(String category) {
  final normalized = category.toUpperCase();
  return normalized == 'DARTS_GOODS' ||
      normalized == 'DARTS_BARREL' ||
      normalized == 'DARTS_FLIGHT' ||
      normalized == 'DARTS_SHAFT' ||
      normalized == 'DARTS_TIP' ||
      normalized == 'DARTS_OTHER';
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
