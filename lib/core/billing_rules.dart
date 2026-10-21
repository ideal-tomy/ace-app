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
    required this.eventItemsTotal,
    required this.normalItemsTotal,
    this.timeChargeAuto = 0,
    this.billingElapsed = Duration.zero,
    this.autoBilledMinutes = 0,
    this.billedMinutesOverride,
  });

  final int foodAndBeverageTotal;
  final int merchandiseTotal;
  final int timeCharge;
  final int timeChargePerPerson;
  final int peopleCount;
  /// イベント課金の明細合計（物販含む）。
  final int eventItemsTotal;
  /// 通常課金の明細合計（物販含む、時間料金は含まない）。
  final int normalItemsTotal;

  /// 手動調整なしの時間料金（全員分）。
  final int timeChargeAuto;

  /// 時間料金の起算から（閉店キャップ後の）現在までの経過。
  final Duration billingElapsed;

  /// 自動計算で請求される時間（分）。料金単位に切り上げた値。
  final int autoBilledMinutes;

  /// スタッフが指定した会計対象時間（分）。null は自動。
  final int? billedMinutesOverride;

  int get billedMinutes => billedMinutesOverride ?? autoBilledMinutes;

  bool get isTimeAdjusted => billedMinutesOverride != null;

  /// 時間調整による減額（0 以上）。
  int get timeChargeAdjustment => timeChargeAuto - timeCharge;

  int get normalTotal => foodAndBeverageTotal + merchandiseTotal;

  /// お客様への合計 = 全明細 + 時間料金。
  int get grandTotal => eventItemsTotal + normalItemsTotal + timeCharge;

  int get eventAmount => eventItemsTotal;

  int get normalAmount => normalItemsTotal + timeCharge;

  // Backward-compatible aliases for existing UI references.
  int get mainDrinksTotal => foodAndBeverageTotal;
  int get separateDrinksTotal => merchandiseTotal;
}

/// 明細の課金区分を解決する（旧データ互換）。
BusinessMode resolveItemBilledAs({
  required CheckItem item,
  required CheckSummary summary,
}) {
  if (item.billedAs != null) return item.billedAs!;
  final nomihodaiAt = summary.nomihodaiStartedAt;
  if (nomihodaiAt != null) {
    return !item.orderedAt.isBefore(nomihodaiAt)
        ? BusinessMode.normal
        : BusinessMode.event;
  }
  // billedAs も切替時刻も無い旧伝票は、伝票の最終モードに従う。
  return summary.billingMode;
}

BillingBreakdown buildBillingBreakdown({
  required CheckSummary summary,
  required List<CheckItem> items,
  required DateTime now,
}) {
  var merchandise = 0;
  var eventItemsTotal = 0;
  var normalItemsTotal = 0;
  for (final item in items) {
    final billedAs = resolveItemBilledAs(item: item, summary: summary);
    if (billedAs == BusinessMode.event) {
      eventItemsTotal += item.lineTotalTaxIncluded;
    } else {
      normalItemsTotal += item.lineTotalTaxIncluded;
    }
    if (isMerchandiseByNameAndCategory(
      name: item.menuNameSnapshot,
      category: item.menuCategorySnapshot,
    )) {
      merchandise += item.lineTotalTaxIncluded;
    }
  }
  // totalTaxIncluded が明細合計と一致しない場合のフォールバック。
  final itemsSum = eventItemsTotal + normalItemsTotal;
  final allItemsTotal = summary.totalTaxIncluded > 0
      ? summary.totalTaxIncluded
      : itemsSum;
  if (itemsSum == 0 && allItemsTotal > 0) {
    // 明細が空で合計だけある場合は最終モードに寄せる。
    if (summary.billingMode == BusinessMode.event) {
      eventItemsTotal = allItemsTotal;
    } else {
      normalItemsTotal = allItemsTotal;
    }
  }
  final foodBase = (allItemsTotal - merchandise).clamp(0, allItemsTotal);
  final peopleCount = summary.peopleCount <= 0 ? 1 : summary.peopleCount;
  final nomihodaiStart = summary.effectiveNomihodaiStartedAt;
  final isNormal = nomihodaiStart != null;
  final billingNow = effectiveBillingNow(
    visitStartedAt: summary.createdAt,
    now: now,
  );
  final elapsed = isNormal
      ? billingNow.difference(nomihodaiStart)
      : Duration.zero;
  final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
  final autoPerPerson = isNormal ? calcTimeCharge(safeElapsed) : 0;
  final override = isNormal ? summary.billingBilledMinutes : null;
  final chargePerPerson = override != null
      ? calcTimeCharge(Duration(minutes: override))
      : autoPerPerson;
  final charge = chargePerPerson * peopleCount;
  final foodWithTimeCharge = foodBase + charge;
  return BillingBreakdown(
    foodAndBeverageTotal: foodWithTimeCharge,
    merchandiseTotal: merchandise,
    timeCharge: charge,
    timeChargePerPerson: chargePerPerson,
    peopleCount: peopleCount,
    eventItemsTotal: eventItemsTotal,
    normalItemsTotal: normalItemsTotal,
    timeChargeAuto: autoPerPerson * peopleCount,
    billingElapsed: safeElapsed,
    autoBilledMinutes: isNormal ? billedMinutesFor(safeElapsed) : 0,
    billedMinutesOverride: override,
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

/// [calcTimeCharge] と同じ料金単位（最初の60分、以降30分）に切り上げた請求時間（分）。
int billedMinutesFor(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  if (minutes <= 60) return 60;
  return 60 + ((minutes - 60) / 30).ceil() * 30;
}

/// 会計対象時間の選択肢。自動計算の請求時間以下を30分刻みで返す（減額のみ）。
List<int> billedMinutesChoices(int autoBilledMinutes) {
  return [for (var m = 60; m <= autoBilledMinutes; m += 30) m];
}

/// 例: 125分 → 「2時間05分」
String formatStayDuration(Duration duration) {
  final minutes = duration.isNegative ? 0 : duration.inMinutes;
  final h = minutes ~/ 60;
  final m = (minutes % 60).toString().padLeft(2, '0');
  return h == 0 ? '$minutes分' : '$h時間$m分';
}

/// 来店日の営業終了時刻（当日または翌日の 3:00）。
DateTime businessClosingAt(DateTime visitStartedAt) {
  var closing = DateTime(
    visitStartedAt.year,
    visitStartedAt.month,
    visitStartedAt.day,
    3,
  );
  if (closing.isBefore(visitStartedAt)) {
    closing = closing.add(const Duration(days: 1));
  }
  return closing;
}

/// 時間料金の累計に使う時刻。閉店（3:00）を過ぎたらそこで止める。
DateTime effectiveBillingNow({
  required DateTime visitStartedAt,
  required DateTime now,
}) {
  final closing = businessClosingAt(visitStartedAt);
  return now.isBefore(closing) ? now : closing;
}

bool isBillingCappedAtClosing({
  required DateTime visitStartedAt,
  required DateTime now,
}) {
  return !now.isBefore(businessClosingAt(visitStartedAt));
}
