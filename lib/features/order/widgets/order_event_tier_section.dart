import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/menu_item.dart';
import '../event_menu_tier_catalog.dart';

class OrderEventTierSection extends StatelessWidget {
  const OrderEventTierSection({
    super.key,
    required this.onTierSelected,
  });

  final ValueChanged<MenuItem> onTierSelected;

  static final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventMenuTierDefs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final def = eventMenuTierDefs[index];
        return _TierRow(
          def: def,
          onTierSelected: onTierSelected,
        );
      },
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.def,
    required this.onTierSelected,
  });

  final EventMenuTierDef def;
  final ValueChanged<MenuItem> onTierSelected;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];
    for (final price in def.regularPrices) {
      buttons.add(
        _TierPriceButton(
          label: OrderEventTierSection._currency.format(price),
          onPressed: () => onTierSelected(
            buildVirtualTierItem(
              groupKey: def.groupKey,
              label: def.label,
              price: price,
              isMega: false,
            ),
          ),
        ),
      );
    }
    final mega = def.megaPrice;
    if (mega != null) {
      buttons.add(
        _TierPriceButton(
          label: 'メガ${OrderEventTierSection._currency.format(mega)}',
          onPressed: () => onTierSelected(
            buildVirtualTierItem(
              groupKey: def.groupKey,
              label: def.label,
              price: mega,
              isMega: true,
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            def.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buttons,
          ),
        ),
      ],
    );
  }
}

class _TierPriceButton extends StatelessWidget {
  const _TierPriceButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}
