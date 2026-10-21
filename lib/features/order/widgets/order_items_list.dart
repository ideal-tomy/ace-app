import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/check_item.dart';
import '../order_flow_state.dart';

/// 伝票画面に常時表示する注文明細（仮注文 + 登録済み）。
class OrderItemsList extends StatelessWidget {
  const OrderItemsList({
    super.key,
    required this.registered,
    required this.draftOrders,
    required this.currency,
    required this.isPaid,
    required this.lineBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CheckItem> registered;
  final Map<String, DraftOrderLine> draftOrders;
  final NumberFormat currency;
  final bool isPaid;
  final bool lineBusy;
  final Future<void> Function(CheckItem item) onEdit;
  final Future<void> Function(CheckItem item) onDelete;

  int get _totalCount {
    final draftQty = draftOrders.values.fold(0, (s, l) => s + l.qty);
    final regQty = registered.fold(0, (s, i) => s + i.qty);
    return draftQty + regQty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAny = registered.isNotEmpty || draftOrders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasAny ? '注文明細（$_totalCount 点）' : '注文明細',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasAny && !isPaid)
          Text(
            'タップまたは編集アイコンで数量変更',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        if (hasAny)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                      for (final line in draftOrders.values) ...[
                        ListTile(
                          leading: const Icon(Icons.schedule, size: 22),
                          title: Text(line.menu.name),
                          subtitle: Text('数量 ${line.qty} ・ 未確定'),
                          trailing: Text(currency.format(line.lineTotal)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                      for (final item in registered) ...[
                        _ItemTile(
                          item: item,
                          currency: currency,
                          canEdit: !isPaid,
                          lineBusy: lineBusy,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'まだ注文がありません',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.currency,
    required this.canEdit,
    required this.lineBusy,
    required this.onEdit,
    required this.onDelete,
  });

  final CheckItem item;
  final NumberFormat currency;
  final bool canEdit;
  final bool lineBusy;
  final Future<void> Function(CheckItem item) onEdit;
  final Future<void> Function(CheckItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: canEdit && !lineBusy ? () => onEdit(item) : null,
      title: Text(item.menuNameSnapshot),
      subtitle: Text('数量 ${item.qty}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currency.format(item.lineTotalTaxIncluded)),
          if (canEdit) ...[
            IconButton(
              tooltip: '数量を変更',
              icon: const Icon(Icons.edit_outlined),
              onPressed: lineBusy ? null : () => onEdit(item),
            ),
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: lineBusy ? null : () => onDelete(item),
            ),
          ],
        ],
      ),
    );
  }
}
