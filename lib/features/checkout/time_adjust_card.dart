import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../models/check_summary.dart';
import 'checkout_staff_billing_card.dart';

/// テスト・単体プレビュー用。本番の会計シートは [CheckoutStaffBillingCard] を使う。
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
  final Future<void> Function(int? minutes) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StaffTimeAdjustControls(
          summary: summary,
          breakdown: breakdown,
          enabled: enabled,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
