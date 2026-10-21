import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../models/check_summary.dart';

/// 通常営業の未会計伝票で、会計対象時間（時間料金）を手動で調整する。
class TimeAdjustCard extends StatelessWidget {
  const TimeAdjustCard({
    super.key,
    required this.summary,
    required this.breakdown,
    required this.currency,
    required this.enabled,
    required this.onChanged,
  });

  final CheckSummary summary;
  final BillingBreakdown breakdown;
  final NumberFormat currency;
  final bool enabled;

  /// null で自動計算に戻す。
  final Future<void> Function(int? minutes) onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final choices = billedMinutesChoices(breakdown.autoBilledMinutes);
    final people = breakdown.peopleCount;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '会計対象時間を選んでください',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in choices.reversed)
                    ChoiceChip(
                      label: Text(
                        '${formatStayDuration(Duration(minutes: m))}'
                        '（${currency.format(calcTimeCharge(Duration(minutes: m)) * people)}）',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: m == breakdown.billedMinutes,
                      onSelected: (_) => Navigator.pop(ctx, m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, -1),
                icon: const Icon(Icons.restart_alt),
                label: const Text('自動計算に戻す'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await onChanged(selected == -1 ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final actualStay = DateTime.now().difference(summary.createdAt);
    final adjustment = breakdown.timeChargeAdjustment;
    final boldStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('実際の滞在: ${formatStayDuration(actualStay)}'),
            Text(
              '自動計算: '
              '${formatStayDuration(Duration(minutes: breakdown.autoBilledMinutes))}'
              '／${currency.format(breakdown.timeChargeAuto)}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '会計対象時間: '
                    '${formatStayDuration(Duration(minutes: breakdown.billedMinutes))}',
                    style: boldStyle,
                  ),
                ),
                OutlinedButton(
                  onPressed: enabled ? () => _openPicker(context) : null,
                  child: const Text('変更'),
                ),
              ],
            ),
            if (adjustment > 0)
              Text(
                '時間調整: −${currency.format(adjustment)}',
                style: boldStyle?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
