import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import 'check_billing_utils.dart';

class CheckStatusCompactCard extends StatelessWidget {
  const CheckStatusCompactCard({
    super.key,
    required this.summary,
    required this.items,
    required this.currency,
    this.draftCount = 0,
    this.draftTotal = 0,
  });

  final CheckSummary summary;
  final List<CheckItem> items;
  final NumberFormat currency;
  final int draftCount;
  final int draftTotal;

  @override
  Widget build(BuildContext context) {
    final total = checkDisplayTotal(summary: summary, items: items);
    final registeredAt = DateFormat('yyyy/MM/dd HH:mm').format(summary.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '登録時間',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              registeredAt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text(
              '現在の金額',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currency.format(total),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (draftCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '仮注文 $draftCount 点（${currency.format(draftTotal)}）は未反映',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
