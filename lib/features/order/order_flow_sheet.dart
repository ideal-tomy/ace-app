import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../models/menu_item.dart';
import '../../models/person_option.dart';
import 'order_flow_state.dart';
import 'widgets/order_confirm_step.dart';
import 'widgets/order_menu_step.dart';
import 'widgets/order_person_step.dart';
import 'widgets/order_quantity_step.dart';

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
  static const _stepTitles = [
    '誰の注文ですか？',
    'メニューを選ぶ',
    '数量を選ぶ',
    '注文内容の確認',
  ];

  late OrderFlowState _state;
  late int _stepIndex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState.copyForSession();
    _stepIndex = 0;
  }

  int get _displayStep => _stepIndex + 1;

  String get _stepTitle => _stepTitles[_stepIndex];

  void _goBack() {
    if (_stepIndex <= 0) {
      _close(submitted: false);
      return;
    }
    setState(() {
      if (_stepIndex == 2) {
        _state.clearCurrentSelection();
      }
      _stepIndex--;
    });
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
      _stepIndex = 1;
    });
  }

  void _onMenuSelected(MenuItem menu) {
    setState(() {
      _state.selectMenu(menu);
      _stepIndex = 2;
    });
  }

  void _onCustomMenuSelected(MenuItem menu) {
    setState(() {
      _state.selectMenu(menu);
      _stepIndex = 2;
    });
  }

  void _onQuantityNext(int qty) {
    setState(() {
      _state.qty = qty;
      _stepIndex = 3;
    });
  }

  void _onContinueOrdering() {
    _state.addCurrentLineToDraft();
    setState(() => _stepIndex = 1);
  }

  Future<void> _onSubmitOrder() async {
    final person = _state.person;
    if (person == null || _submitting) return;

    final linesToSubmit = <DraftOrderLine>[
      ..._state.draftOrders.values,
      if (_state.selectedMenu != null)
        DraftOrderLine(menu: _state.selectedMenu!, qty: _state.qty),
    ];
    if (linesToSubmit.isEmpty) return;

    setState(() => _submitting = true);
    try {
      for (final line in linesToSubmit) {
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
        _goBack();
      },
      child: SizedBox(
        height: screenHeight * 0.85,
        child: Column(
          children: [
            _FlowHeader(
              title: _stepTitle,
              stepLabel: '$_displayStep/4',
              personName: _stepIndex > 0 ? person?.displayName : null,
              onBack: _goBack,
              onClose: () => _close(submitted: false),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return OrderPersonStep(
          checkRepository: widget.checkRepository,
          onPersonSelected: _onPersonSelected,
        );
      case 1:
        final person = _state.person;
        if (person == null) {
          return const Center(child: Text('来店客が選択されていません'));
        }
        return OrderMenuStep(
          person: person,
          checkRepository: widget.checkRepository,
          menuRepository: widget.menuRepository,
          adminAuthService: widget.adminAuthService,
          onMenuSelected: _onMenuSelected,
          onCustomMenuSelected: _onCustomMenuSelected,
        );
      case 2:
        final menu = _state.selectedMenu;
        if (menu == null) {
          return const Center(child: Text('メニューが選択されていません'));
        }
        return OrderQuantityStep(
          menu: menu,
          initialQty: _state.qty,
          onNext: _onQuantityNext,
        );
      case 3:
        final menu = _state.selectedMenu;
        if (menu == null) {
          return const Center(child: Text('メニューが選択されていません'));
        }
        return OrderConfirmStep(
          state: _state,
          submitting: _submitting,
          onContinue: _onContinueOrdering,
          onSubmit: _onSubmitOrder,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
    required this.title,
    required this.stepLabel,
    required this.onBack,
    required this.onClose,
    this.personName,
  });

  final String title;
  final String stepLabel;
  final String? personName;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                      Text(
                        personName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orderCtaColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stepLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: _orderCtaColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
