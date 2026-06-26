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
  final isNormal = summary.billingMode == BusinessMode.normal;
  final isPaid = summary.status == 'paid';
  if (isPaid && summary.finalAmount != null) {
    return summary.finalAmount!;
  }
  return isNormal ? breakdown.normalTotal : summary.totalTaxIncluded;
}
