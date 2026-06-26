import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/menu_item.dart';

class OrderQuantityStep extends StatefulWidget {
  const OrderQuantityStep({
    super.key,
    required this.menu,
    required this.initialQty,
    required this.onNext,
  });

  final MenuItem menu;
  final int initialQty;
  final ValueChanged<int> onNext;

  @override
  State<OrderQuantityStep> createState() => _OrderQuantityStepState();
}

class _OrderQuantityStepState extends State<OrderQuantityStep> {
  static final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal = widget.menu.priceTaxIncluded * _qty;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text(
            widget.menu.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '単価 ${_currency.format(widget.menu.priceTaxIncluded)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                iconSize: 32,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$_qty',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() => _qty++),
                iconSize: 32,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '小計 ${_currency.format(lineTotal)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => widget.onNext(_qty),
              child: const Text('次へ'),
            ),
          ),
        ],
      ),
    );
  }
}
