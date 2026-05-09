import 'package:flutter/material.dart';

import '../../data/expense_accounts_master.dart';
import '../../models/expense_account_item.dart';

/// 経費科目（マスタ一覧から選択）。
///
/// [wide] が true のときは [SearchAnchor.bar]、[wide] が false のときはボトムシート検索。
class ExpenseAccountPicker extends StatelessWidget {
  const ExpenseAccountPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.wide,
    required this.enabled,
  });

  final ExpenseAccountItem? selected;
  final ValueChanged<ExpenseAccountItem?> onSelected;
  final bool wide;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return _WideExpenseAccountField(
        selected: selected,
        onSelected: onSelected,
        enabled: enabled,
      );
    }
    return _CompactExpenseAccountTile(
      selected: selected,
      enabled: enabled,
      onTap: enabled ? () => _openBottomSheetPicker(context) : null,
    );
  }

  Future<void> _openBottomSheetPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<ExpenseAccountItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, scrollController) =>
                _ExpenseAccountSheetBody(scrollController: scrollController),
          ),
        );
      },
    );
    if (picked != null && context.mounted) {
      onSelected(picked);
    }
  }
}

class _CompactExpenseAccountTile extends StatelessWidget {
  const _CompactExpenseAccountTile({
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ExpenseAccountItem? selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = selected?.labelJa;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '科目',
          hintText: 'タップして選択',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.keyboard_arrow_down),
          enabled: enabled,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: label == null || label.isEmpty
              ? Text(
                  '',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.hintColor,
                  ),
                )
              : Text(
                  label,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

/// 広い画面用: [SearchAnchor.bar] で入力しながら候補選択。
class _WideExpenseAccountField extends StatefulWidget {
  const _WideExpenseAccountField({
    required this.selected,
    required this.onSelected,
    required this.enabled,
  });

  final ExpenseAccountItem? selected;
  final ValueChanged<ExpenseAccountItem?> onSelected;
  final bool enabled;

  @override
  State<_WideExpenseAccountField> createState() =>
      _WideExpenseAccountFieldState();
}

class _WideExpenseAccountFieldState extends State<_WideExpenseAccountField> {
  late final SearchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SearchController();
    _syncTextFromSelection();
  }

  void _syncTextFromSelection() {
    final t = widget.selected?.labelJa ?? '';
    if (_controller.text != t) {
      _controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
  }

  @override
  void didUpdateWidget(_WideExpenseAccountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _syncTextFromSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<ExpenseAccountItem> _filter(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return List.of(kExpenseAccountItems);
    final qLow = q.toLowerCase();
    return kExpenseAccountItems
        .where(
          (e) => e.labelJa.contains(q) || e.id.toLowerCase().contains(qLow),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tooltipLabel = widget.selected?.labelJa ?? '';
    return Tooltip(
      message: tooltipLabel.length > 18 ? tooltipLabel : '',
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: SearchAnchor.bar(
            barLeading: const Icon(Icons.balance_outlined, size: 22),
            barHintText: widget.selected == null ? '科目を検索して選択' : null,
            isFullScreen: false,
            searchController: _controller,
            textCapitalization: TextCapitalization.none,
            enabled: widget.enabled,
            suggestionsBuilder:
                (BuildContext context, SearchController controller) {
                  final filtered = _filter(controller.text);
                  if (filtered.isEmpty) {
                    return <Widget>[
                      const ListTile(title: Text('該当する科目がありません')),
                    ];
                  }
                  return filtered.map((item) {
                    return ListTile(
                      title: Text(item.labelJa),
                      subtitle: Text(
                        item.id,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () {
                        widget.onSelected(item);
                        controller
                          ..text = item.labelJa
                          ..selection = TextSelection.collapsed(
                            offset: controller.text.length,
                          )
                          ..closeView('');
                      },
                    );
                  }).toList();
                },
          ),
        ),
      ),
    );
  }
}

class _ExpenseAccountSheetBody extends StatefulWidget {
  const _ExpenseAccountSheetBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_ExpenseAccountSheetBody> createState() =>
      _ExpenseAccountSheetBodyState();
}

class _ExpenseAccountSheetBodyState extends State<_ExpenseAccountSheetBody> {
  String _filter = '';

  Iterable<ExpenseAccountItem> get _filtered {
    final q = _filter.trim();
    if (q.isEmpty) return kExpenseAccountItems;
    final qLow = q.toLowerCase();
    return kExpenseAccountItems.where(
      (e) => e.labelJa.contains(q) || e.id.toLowerCase().contains(qLow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '科目を検索',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                title: Text(item.labelJa),
                subtitle: Text(
                  item.id,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
