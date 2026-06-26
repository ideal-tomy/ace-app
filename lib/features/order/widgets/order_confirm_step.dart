import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../order_flow_state.dart';

class OrderConfirmStep extends StatelessWidget {
  const OrderConfirmStep({
    super.key,
    required this.state,
    required this.submitting,
    required this.onContinue,
    required this.onSubmit,
  });

  final OrderFlowState state;
  final bool submitting;
  final VoidCallback onContinue;
  final VoidCallback onSubmit;

  static final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final menu = state.selectedMenu!;
    final qty = state.qty;
    final currentTotal = state.currentLineTotal;
    final priorDraft = Map<String, DraftOrderLine>.from(state.draftOrders);
    final priorCount = priorDraft.values.fold(0, (s, l) => s + l.qty);
    final priorTotal = priorDraft.values.fold(0, (s, l) => s + l.lineTotal);
    final allCount = priorCount + qty;
    final allTotal = priorTotal + currentTotal;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '注文内容の確認',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今回の注文',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          menu.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        _currency.format(currentTotal),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '数量 $qty',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (priorDraft.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('これまでの仮注文（$priorCount 点）'),
              subtitle: Text(_currency.format(priorTotal)),
              children: priorDraft.values
                  .map(
                    (line) => ListTile(
                      dense: true,
                      title: Text(line.menu.name),
                      subtitle: Text('数量 ${line.qty}'),
                      trailing: Text(_currency.format(line.lineTotal)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const Spacer(),
          if (priorDraft.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '確定時の合計: $allCount 点 ・ ${_currency.format(allTotal)}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: Text(submitting ? '確定中...' : '注文を確定'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: submitting ? null : onContinue,
              child: const Text('注文を続ける'),
            ),
          ),
        ],
      ),
    );
  }
}
