import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import 'check_billing_utils.dart';

class CheckBillingSummaryCard extends StatelessWidget {
  const CheckBillingSummaryCard({
    super.key,
    required this.summary,
    required this.items,
    required this.currency,
  });

  final CheckSummary summary;
  final List<CheckItem> items;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final breakdown = buildBillingBreakdown(
      summary: summary,
      items: items,
      now: DateTime.now(),
    );
    final isNormal = summary.billingMode == BusinessMode.normal;
    final isPaid = summary.status == 'paid';
    final total = checkDisplayTotal(summary: summary, items: items);
    final timeCharge = isPaid
        ? (summary.timeChargeFinal ?? breakdown.timeCharge)
        : breakdown.timeCharge;
    final merchandise = isPaid
        ? (summary.merchandiseFinal ??
              summary.separateFinal ??
              breakdown.merchandiseTotal)
        : breakdown.merchandiseTotal;
    final foodAndBeverage = isPaid
        ? (total - merchandise).clamp(0, total)
        : breakdown.foodAndBeverageTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    summary.customerNameSnapshot,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('営業モード: ${summary.billingMode.label}'),
                  Text(
                    '登録時間: ${DateFormat('yyyy/MM/dd HH:mm').format(summary.createdAt)}',
                  ),
                  const SizedBox(height: 4),
                  Text('飲食: ${currency.format(foodAndBeverage)}'),
                  Text('物販: ${currency.format(merchandise)}'),
                  if (isNormal)
                    Text(
                      '時間料金(飲食に含む): ${currency.format(timeCharge)} '
                      '(${currency.format(breakdown.timeChargePerPerson)} × ${breakdown.peopleCount}名)',
                    ),
                  Text(
                    '内税10%: ${currency.format(summary.taxAmount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isPaid) const Text('※会計確定済み（固定金額）'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '合計',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  currency.format(total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
