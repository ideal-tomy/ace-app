import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../core/payment_method.dart';
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
    final now = DateTime.now();
    final breakdown = buildBillingBreakdown(
      summary: summary,
      items: items,
      now: now,
    );
    final isNormal = summary.billingMode == BusinessMode.normal;
    final isPaid = summary.status == 'paid';
    final isCappedAtClosing =
        !isPaid &&
        isNormal &&
        isBillingCappedAtClosing(visitStartedAt: summary.createdAt, now: now);
    final total = checkDisplayTotal(summary: summary, items: items);
    final timeCharge = isPaid
        ? (summary.timeChargeFinal ?? breakdown.timeCharge)
        : breakdown.timeCharge;
    final merchandise = isPaid
        ? (summary.merchandiseFinal ??
              summary.separateFinal ??
              breakdown.merchandiseTotal)
        : breakdown.merchandiseTotal;
    final eventAmount = isPaid
        ? (summary.eventAmountFinal ?? breakdown.eventAmount)
        : breakdown.eventAmount;
    final normalItems = isPaid
        ? ((summary.normalAmountFinal ?? breakdown.normalAmount) - timeCharge)
              .clamp(0, 1 << 30)
        : breakdown.normalItemsTotal;
    final nomihodaiAt = summary.effectiveNomihodaiStartedAt;
    final timeAdjustment = isPaid
        ? (summary.timeChargeAdjustmentAmount ?? 0)
        : breakdown.timeChargeAdjustment;
    final billedMinutesFinal = summary.billingBilledMinutesFinal;
    final departedAt = summary.departedAt ?? summary.closedAt;

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
                  Text('営業モード: ${summary.modeBadgeLabel}'),
                  Text(
                    '登録時間: ${DateFormat('yyyy/MM/dd HH:mm').format(summary.createdAt)}',
                  ),
                  if (summary.switchedFromEvent && nomihodaiAt != null)
                    Text('投げ放題開始: ${DateFormat('HH:mm').format(nomihodaiAt)}'),
                  if (isPaid && departedAt != null)
                    Text(
                      '退店: ${DateFormat('MM/dd HH:mm').format(departedAt)}'
                      '（滞在 ${formatStayDuration(departedAt.difference(summary.createdAt))}）',
                    ),
                  if (isPaid && isNormal && billedMinutesFinal != null)
                    Text(
                      '会計対象時間: '
                      '${formatStayDuration(Duration(minutes: billedMinutesFinal))}',
                    ),
                  const SizedBox(height: 4),
                  if (eventAmount > 0)
                    Text('イベント注文: ${currency.format(eventAmount)}'),
                  if (isNormal && timeCharge > 0)
                    Text(
                      '投げ放題時間料金: ${currency.format(timeCharge)} '
                      '(${currency.format(timeCharge ~/ breakdown.peopleCount)} × ${breakdown.peopleCount}名)',
                    ),
                  if (isNormal && timeAdjustment != 0)
                    Text(
                      '時間調整: ${formatTimeAdjustment(timeAdjustment, currency.format)}',
                    ),
                  if (normalItems > 0)
                    Text('切替後・通常注文: ${currency.format(normalItems)}'),
                  if (merchandise > 0)
                    Text('物販: ${currency.format(merchandise)}'),
                  if (eventAmount == 0 &&
                      normalItems == 0 &&
                      timeCharge == 0 &&
                      merchandise == 0)
                    Text('飲食: ${currency.format(0)}'),
                  if (isCappedAtClosing)
                    Text(
                      '※閉店時刻(3:00)時点で時間料金を確定',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    '内税10%: ${currency.format(summary.taxAmount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (summary.paymentMethod != null)
                    Text('支払: ${summary.paymentMethod!.label}'),
                  if (isPaid) const Text('※会計確定済み（固定金額）'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('合計', style: Theme.of(context).textTheme.bodySmall),
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
