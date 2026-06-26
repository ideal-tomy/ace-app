import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/check_item.dart';
import 'order_flow_state.dart';

Future<void> showOrderItemsSheet(
  BuildContext context, {
  required List<CheckItem> registered,
  required Map<String, DraftOrderLine> draftOrders,
  required NumberFormat currency,
  required bool isPaid,
  required bool lineBusy,
  required Future<void> Function(CheckItem item) onEdit,
  required Future<void> Function(CheckItem item) onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _OrderItemsSheet(
      registered: registered,
      draftOrders: draftOrders,
      currency: currency,
      isPaid: isPaid,
      lineBusy: lineBusy,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _OrderItemsSheet extends StatelessWidget {
  const _OrderItemsSheet({
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final hasAny = registered.isNotEmpty || draftOrders.isNotEmpty;

    return SizedBox(
      height: screenHeight * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '注文明細',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (hasAny)
                        Text(
                          '$_totalCount 点',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (!isPaid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'タップまたは編集アイコンで数量変更',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: hasAny
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
                  )
                : Center(
                    child: Text(
                      'まだ注文がありません',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ],
      ),
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
