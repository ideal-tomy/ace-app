import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/check_item.dart';

Future<bool> confirmRemoveCheckItem(
  BuildContext context, {
  required CheckItem item,
  required NumberFormat currency,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('明細の削除'),
      content: Text(
        '次の注文を削除しますか？\n\n'
        '${item.menuNameSnapshot}\n'
        '数量 ${item.qty} ・ ${currency.format(item.lineTotalTaxIncluded)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('削除'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}

Future<int?> showEditCheckItemQtyDialog(
  BuildContext context, {
  required CheckItem item,
  required NumberFormat currency,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _EditQtyDialog(item: item, currency: currency),
  );
}

class _EditQtyDialog extends StatefulWidget {
  const _EditQtyDialog({required this.item, required this.currency});

  final CheckItem item;
  final NumberFormat currency;

  @override
  State<_EditQtyDialog> createState() => _EditQtyDialogState();
}

class _EditQtyDialogState extends State<_EditQtyDialog> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.item.qty;
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal = widget.item.unitPriceTaxIncluded * _qty;
    final changed = _qty != widget.item.qty;

    return AlertDialog(
      title: const Text('数量の変更'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.menuNameSnapshot,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '単価 ${widget.currency.format(widget.item.unitPriceTaxIncluded)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_qty', style: Theme.of(context).textTheme.headlineSmall),
                IconButton(
                  onPressed: () => setState(() => _qty++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('小計 ${widget.currency.format(lineTotal)}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: changed ? () => Navigator.pop(context, _qty) : null,
          child: const Text('変更する'),
        ),
      ],
    );
  }
}
