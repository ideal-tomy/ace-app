import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../core/business_mode.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../shared/check_billing_utils.dart';

/// 会計ボトムシート向け。説明ラベルを省き、スタッフが一目で確認できる表示。
class CheckoutStaffBillingCard extends StatefulWidget {
  const CheckoutStaffBillingCard({
    super.key,
    required this.summary,
    required this.items,
    required this.currency,
    required this.breakdown,
    this.timeAdjustEnabled = false,
    this.onBilledMinutesChanged,
  });

  final CheckSummary summary;
  final List<CheckItem> items;
  final NumberFormat currency;
  final BillingBreakdown breakdown;
  final bool timeAdjustEnabled;
  final Future<void> Function(int? minutes)? onBilledMinutesChanged;

  bool get _showTimeAdjust =>
      summary.billingMode == BusinessMode.normal &&
      summary.status != 'paid' &&
      onBilledMinutesChanged != null;

  @override
  State<CheckoutStaffBillingCard> createState() =>
      _CheckoutStaffBillingCardState();
}

class _CheckoutStaffBillingCardState extends State<CheckoutStaffBillingCard> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final breakdown = widget.breakdown;
    final total = checkDisplayTotal(summary: summary, items: widget.items);
    final timeCharge = breakdown.timeCharge;
    final orderTotal = breakdown.grandTotal - timeCharge;
    const tabular = [FontFeature.tabularFigures()];
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final amountStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  DateFormat('HH:mm').format(summary.createdAt),
                  style: titleStyle?.copyWith(fontFeatures: tabular),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatElapsed(DateTime.now().difference(summary.createdAt)),
                  style: titleStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (timeCharge > 0) _amountRow('時間料金', timeCharge, widget.currency),
            if (orderTotal > 0) _amountRow('注文', orderTotal, widget.currency),
            if (timeCharge == 0 && orderTotal == 0)
              _amountRow('注文', 0, widget.currency),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                Text('合計', style: titleStyle),
                const Spacer(),
                Text(
                  widget.currency.format(total),
                  style: amountStyle?.copyWith(fontFeatures: tabular),
                ),
              ],
            ),
            if (widget._showTimeAdjust) ...[
              const SizedBox(height: 16),
              StaffTimeAdjustControls(
                summary: summary,
                breakdown: buildBillingBreakdown(
                  summary: summary,
                  items: widget.items,
                  now: DateTime.now(),
                  includeCompletedPeriods: false,
                ),
                enabled: widget.timeAdjustEnabled,
                onChanged: widget.onBilledMinutesChanged!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatElapsed(Duration elapsed) {
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    if (safe.inHours < 1) {
      final sec = safe.inSeconds % 60;
      return '${safe.inMinutes}分${sec.toString().padLeft(2, '0')}秒';
    }
    final hours = safe.inHours;
    final rem = safe.inMinutes % 60;
    return rem == 0 ? '$hours時間' : '$hours時間$rem分';
  }

  Widget _amountRow(String label, int amount, NumberFormat currency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            currency.format(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 請求時間の ±30 分調整（会計シート・テストから共用）。
class StaffTimeAdjustControls extends StatelessWidget {
  const StaffTimeAdjustControls({
    super.key,
    required this.summary,
    required this.breakdown,
    required this.enabled,
    required this.onChanged,
  });

  final CheckSummary summary;
  final BillingBreakdown breakdown;
  final bool enabled;
  final Future<void> Function(int? minutes) onChanged;

  @override
  Widget build(BuildContext context) {
    final maximum = maxManualBilledMinutes(summary);
    final minutes = breakdown.billedMinutes;
    final billedStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.normalBillingPeriods.isNotEmpty)
          const Text('今回の通常営業の会計対象時間', textAlign: TextAlign.center),
        Text(
          formatStayDuration(Duration(minutes: minutes)),
          textAlign: TextAlign.center,
          style: billedStyle,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: enabled && minutes > 60
                    ? () => onChanged(minutes - 30)
                    : null,
                child: const Text('−30分'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: enabled && minutes < maximum
                    ? () => onChanged(minutes + 30)
                    : null,
                child: const Text('＋30分'),
              ),
            ),
          ],
        ),
        if (breakdown.isTimeAdjusted) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: enabled ? () => onChanged(null) : null,
              icon: const Icon(Icons.restart_alt, size: 20),
              label: const Text('自動に戻す'),
            ),
          ),
        ],
      ],
    );
  }
}
