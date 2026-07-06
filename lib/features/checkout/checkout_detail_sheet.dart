import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/check_repository.dart';
import '../../models/check_item.dart';
import '../../models/person_option.dart';
import '../shared/check_billing_summary_card.dart';
import '../shared/check_item_actions.dart';

Future<bool> showCheckoutDetailSheet(
  BuildContext context, {
  required PersonOption person,
  required CheckRepository checkRepository,
  required bool canOperate,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => CheckoutDetailSheet(
      person: person,
      checkRepository: checkRepository,
      canOperate: canOperate,
    ),
  ).then((value) => value ?? false);
}

class CheckoutDetailSheet extends StatefulWidget {
  const CheckoutDetailSheet({
    super.key,
    required this.person,
    required this.checkRepository,
    required this.canOperate,
  });

  final PersonOption person;
  final CheckRepository checkRepository;
  final bool canOperate;

  @override
  State<CheckoutDetailSheet> createState() => _CheckoutDetailSheetState();
}

class _CheckoutDetailSheetState extends State<CheckoutDetailSheet> {
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  bool _removingLine = false;
  bool _updatingLine = false;
  bool _finalizing = false;

  bool get _lineBusy => _removingLine || _updatingLine;

  Future<void> _confirmRemoveLine(CheckItem item) async {
    if (_removingLine) return;
    final ok = await confirmRemoveCheckItem(
      context,
      item: item,
      currency: _currency,
    );
    if (!ok || !mounted) return;
    setState(() => _removingLine = true);
    try {
      await widget.checkRepository.removeOrderItem(
        checkId: widget.person.openCheckId,
        itemId: item.id,
        lineTotalTaxIncluded: item.lineTotalTaxIncluded,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('明細を削除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _removingLine = false);
    }
  }

  Future<void> _editLineQty(CheckItem item) async {
    if (!widget.canOperate || _lineBusy) return;
    final newQty = await showEditCheckItemQtyDialog(
      context,
      item: item,
      currency: _currency,
    );
    if (newQty == null || newQty == item.qty || !mounted) return;
    setState(() => _updatingLine = true);
    try {
      await widget.checkRepository.updateOrderItemQty(
        checkId: widget.person.openCheckId,
        item: item,
        newQty: newQty,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('数量を変更しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('変更に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingLine = false);
    }
  }

  Future<void> _finalize() async {
    if (!widget.canOperate || _finalizing) return;
    setState(() => _finalizing = true);
    try {
      await widget.checkRepository.finalizeCheck(widget.person.openCheckId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('会計確定に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: screenHeight * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '会計内容',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        widget.person.displayName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: StreamBuilder(
                stream: widget.checkRepository.streamCheckSummary(
                  widget.person.openCheckId,
                ),
                builder: (context, summarySnapshot) {
                  if (!summarySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final summary = summarySnapshot.data!;
                  final isPaid = summary.status == 'paid';

                  return StreamBuilder<List<CheckItem>>(
                    stream: widget.checkRepository.streamCheckItems(
                      widget.person.openCheckId,
                    ),
                    builder: (context, itemsSnapshot) {
                      if (itemsSnapshot.hasError) {
                        return Center(
                          child: Text('明細取得エラー: ${itemsSnapshot.error}'),
                        );
                      }
                      if (!itemsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = itemsSnapshot.data!;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: CheckBillingSummaryCard(
                              summary: summary,
                              items: items,
                              currency: _currency,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: items.isEmpty
                                ? const Center(
                                    child: Text('注文履歴はまだありません'),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    itemCount: items.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      final editable = widget.canOperate &&
                                          !isPaid &&
                                          !_lineBusy;
                                      return ListTile(
                                        dense: true,
                                        onTap: editable
                                            ? () => _editLineQty(item)
                                            : null,
                                        title: Text(item.menuNameSnapshot),
                                        subtitle: Text('数量 ${item.qty}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _currency.format(
                                                item.lineTotalTaxIncluded,
                                              ),
                                            ),
                                            if (widget.canOperate && !isPaid) ...[
                                              IconButton(
                                                tooltip: '数量を変更',
                                                onPressed: _lineBusy
                                                    ? null
                                                    : () => _editLineQty(item),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'この明細を削除',
                                                onPressed: _lineBusy
                                                    ? null
                                                    : () =>
                                                          _confirmRemoveLine(
                                                            item,
                                                          ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.canOperate && !_finalizing && !_lineBusy
                    ? _finalize
                    : null,
                child: Text(_finalizing ? '会計確定中...' : '会計確定'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
