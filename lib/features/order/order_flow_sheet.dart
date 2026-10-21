import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';
import 'order_flow_state.dart';
import 'widgets/order_menu_step.dart';
import 'widgets/order_person_step.dart';

const _orderCtaColor = Color(0xFFEA580C);

/// 注文フローの結果
class OrderFlowResult {
  const OrderFlowResult({
    required this.person,
    required this.draftOrders,
    required this.submitted,
  });

  final PersonOption? person;
  final Map<String, DraftOrderLine> draftOrders;
  final bool submitted;
}

Future<OrderFlowResult?> showOrderFlowSheet(
  BuildContext context, {
  required CheckRepository checkRepository,
  required MenuRepository menuRepository,
  required AdminAuthService adminAuthService,
  required OrderFlowState initialState,
}) {
  return showModalBottomSheet<OrderFlowResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => OrderFlowSheet(
      checkRepository: checkRepository,
      menuRepository: menuRepository,
      adminAuthService: adminAuthService,
      initialState: initialState,
    ),
  );
}

class OrderFlowSheet extends StatefulWidget {
  const OrderFlowSheet({
    super.key,
    required this.checkRepository,
    required this.menuRepository,
    required this.adminAuthService,
    required this.initialState,
  });

  final CheckRepository checkRepository;
  final MenuRepository menuRepository;
  final AdminAuthService adminAuthService;
  final OrderFlowState initialState;

  @override
  State<OrderFlowSheet> createState() => _OrderFlowSheetState();
}

class _OrderFlowSheetState extends State<OrderFlowSheet> {
  late OrderFlowState _state;
  bool _pickingPerson = false;
  bool _submitting = false;
  bool _cartExpanded = false;

  static final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _state = widget.initialState.copyForSession();
    _pickingPerson = _state.person == null;
  }

  void _close({required bool submitted}) {
    Navigator.pop(
      context,
      OrderFlowResult(
        person: _state.person,
        draftOrders: submitted ? {} : Map.from(_state.draftOrders),
        submitted: submitted,
      ),
    );
  }

  void _onPersonSelected(PersonOption person) {
    setState(() {
      _state.person = person;
      _pickingPerson = false;
    });
  }

  void _addMenuToCart(MenuItem menu) {
    final existing = _state.draftOrders[menu.id];
    setState(() {
      if (existing == null) {
        _state.draftOrders[menu.id] = DraftOrderLine(menu: menu, qty: 1);
      } else {
        _state.draftOrders[menu.id] = existing.copyWith(qty: existing.qty + 1);
      }
      _cartExpanded = true;
    });
  }

  void _setQty(String menuId, int qty) {
    setState(() {
      if (qty <= 0) {
        _state.draftOrders.remove(menuId);
      } else {
        final line = _state.draftOrders[menuId];
        if (line != null) {
          _state.draftOrders[menuId] = line.copyWith(qty: qty);
        }
      }
    });
  }

  Future<void> _onSubmitOrder() async {
    final person = _state.person;
    if (person == null || _submitting) return;
    final lines = _state.draftOrders.values.toList();
    if (lines.isEmpty) return;

    setState(() => _submitting = true);
    try {
      for (final line in lines) {
        await widget.checkRepository.addOrderItem(
          checkId: person.openCheckId,
          menu: line.menu,
          qty: line.qty,
        );
      }
      if (!mounted) return;
      _close(submitted: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注文確定に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final person = _state.person;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_pickingPerson && widget.initialState.person == null) {
          setState(() => _pickingPerson = true);
          return;
        }
        _close(submitted: false);
      },
      child: SizedBox(
        height: screenHeight * 0.9,
        child: Column(
          children: [
            _FlowHeader(
              title: _pickingPerson ? '誰の注文ですか？' : 'メニューを選ぶ',
              personName: !_pickingPerson ? person?.displayName : null,
              modeLabel: !_pickingPerson ? person?.modeBadgeLabel : null,
              onBack: () {
                if (!_pickingPerson && widget.initialState.person == null) {
                  setState(() => _pickingPerson = true);
                  return;
                }
                _close(submitted: false);
              },
              onClose: () => _close(submitted: false),
              onChangePerson: !_pickingPerson && person != null
                  ? () => setState(() => _pickingPerson = true)
                  : null,
            ),
            const Divider(height: 1),
            Expanded(
              child: _pickingPerson
                  ? OrderPersonStep(
                      checkRepository: widget.checkRepository,
                      onPersonSelected: _onPersonSelected,
                    )
                  : (person == null
                      ? const Center(child: Text('来店客が選択されていません'))
                      : OrderMenuStep(
                          person: person,
                          checkRepository: widget.checkRepository,
                          menuRepository: widget.menuRepository,
                          adminAuthService: widget.adminAuthService,
                          onMenuSelected: _addMenuToCart,
                          onCustomMenuSelected: _addMenuToCart,
                        )),
            ),
            if (!_pickingPerson && person != null)
              _CartBar(
                draftOrders: _state.draftOrders,
                expanded: _cartExpanded,
                submitting: _submitting,
                currency: _currency,
                onToggleExpand: () =>
                    setState(() => _cartExpanded = !_cartExpanded),
                onQtyChanged: _setQty,
                onSubmit: _onSubmitOrder,
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
    required this.title,
    required this.onBack,
    required this.onClose,
    this.personName,
    this.modeLabel,
    this.onChangePerson,
  });

  final String title;
  final String? personName;
  final String? modeLabel;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback? onChangePerson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (personName != null)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          personName!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (modeLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          modeLabel!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: _orderCtaColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          if (onChangePerson != null)
            TextButton(
              onPressed: onChangePerson,
              child: const Text('伝票切り替え'),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.draftOrders,
    required this.expanded,
    required this.submitting,
    required this.currency,
    required this.onToggleExpand,
    required this.onQtyChanged,
    required this.onSubmit,
  });

  final Map<String, DraftOrderLine> draftOrders;
  final bool expanded;
  final bool submitting;
  final NumberFormat currency;
  final VoidCallback onToggleExpand;
  final void Function(String menuId, int qty) onQtyChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final lines = draftOrders.values.toList();
    final count = lines.fold(0, (s, l) => s + l.qty);
    final total = lines.fold(0, (s, l) => s + l.lineTotal);

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (expanded && lines.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.menu.name),
                      subtitle: Text(currency.format(line.lineTotal)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: submitting
                                ? null
                                : () => onQtyChanged(
                                    line.menu.id,
                                    line.qty - 1,
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '${line.qty}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: submitting
                                ? null
                                : () => onQtyChanged(
                                    line.menu.id,
                                    line.qty + 1,
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: lines.isEmpty ? null : onToggleExpand,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            expanded
                                ? Icons.expand_more
                                : Icons.shopping_cart_outlined,
                            color: _orderCtaColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            count == 0
                                ? 'カート空'
                                : '$count点・${currency.format(total)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: submitting || lines.isEmpty ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _orderCtaColor,
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(submitting ? '確定中...' : '注文を確定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
