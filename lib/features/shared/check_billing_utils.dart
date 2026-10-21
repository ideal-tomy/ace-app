import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';

int checkDisplayTotal({
  required CheckSummary summary,
  required List<CheckItem> items,
  DateTime? now,
}) {
  final breakdown = buildBillingBreakdown(
    summary: summary,
    items: items,
    now: now ?? DateTime.now(),
  );
  final isPaid = summary.status == 'paid';
  if (isPaid && summary.finalAmount != null) {
    return summary.finalAmount!;
  }
  // イベントのみなら明細合計、通常（切替含む）なら明細＋時間料金。
  if (summary.billingMode == BusinessMode.normal ||
      summary.switchedFromEvent) {
    return breakdown.grandTotal;
  }
  return summary.totalTaxIncluded > 0
      ? summary.totalTaxIncluded
      : breakdown.eventItemsTotal;
}
