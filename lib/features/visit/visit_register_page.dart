import 'package:flutter/material.dart';

import '../../core/business_mode.dart';
import '../../data/repositories/check_repository.dart';
import '../../data/repositories/customer_repository.dart';

class VisitRegisterPage extends StatefulWidget {
  const VisitRegisterPage({super.key});

  static const routeName = '/visit-register';

  @override
  State<VisitRegisterPage> createState() => _VisitRegisterPageState();
}

class _VisitRegisterPageState extends State<VisitRegisterPage> {
  final _controller = TextEditingController();
  final _customerRepository = CustomerRepository();
  final _checkRepository = CheckRepository();
  int _peopleCount = 1;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('名前またはあだ名を入力してください')));
      return;
    }

    final billingMode = await showDialog<BusinessMode>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BusinessModeConfirmDialog(
        customerName: name,
        peopleCount: _peopleCount,
      ),
    );
    if (billingMode == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _customerRepository.createCustomerIfNeeded(name);
      await _checkRepository.createOpenCheck(
        customerName: name,
        billingMode: billingMode,
        peopleCount: _peopleCount,
      );
      if (mounted) {
        Navigator.pop(context, name);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登録に失敗しました: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('来店登録')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              StreamBuilder<List<String>>(
                stream: _customerRepository.streamCustomerNames(),
                builder: (context, snapshot) {
                  final names = snapshot.data ?? const [];
                  return Autocomplete<String>(
                    optionsBuilder: (value) {
                      if (value.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return names.where(
                        (n) =>
                            n.toLowerCase().contains(value.text.toLowerCase()),
                      );
                    },
                    onSelected: (value) => _controller.text = value,
                    fieldViewBuilder:
                        (context, textController, focusNode, onSubmit) {
                          textController.text = _controller.text;
                          return TextField(
                            controller: textController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: '来店者名',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => _controller.text = v,
                          );
                        },
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('人数'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _saving || _peopleCount <= 1
                        ? null
                        : () => setState(() => _peopleCount--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '$_peopleCount名',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _peopleCount++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _register,
                  child: Text(_saving ? '登録中...' : '来店登録して伝票作成'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessModeConfirmDialog extends StatefulWidget {
  const _BusinessModeConfirmDialog({
    required this.customerName,
    required this.peopleCount,
  });

  final String customerName;
  final int peopleCount;

  @override
  State<_BusinessModeConfirmDialog> createState() =>
      _BusinessModeConfirmDialogState();
}

class _BusinessModeConfirmDialogState extends State<_BusinessModeConfirmDialog> {
  BusinessMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('営業モードを選択'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.customerName} さん（${widget.peopleCount}名）の登録方法を選んでください',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ModeOptionTile(
              mode: BusinessMode.event,
              selected: _selectedMode == BusinessMode.event,
              onTap: () => setState(() => _selectedMode = BusinessMode.event),
            ),
            const SizedBox(height: 8),
            _ModeOptionTile(
              mode: BusinessMode.normal,
              selected: _selectedMode == BusinessMode.normal,
              onTap: () => setState(() => _selectedMode = BusinessMode.normal),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _selectedMode == null
              ? null
              : () => Navigator.pop(context, _selectedMode),
          child: const Text('登録する'),
        ),
      ],
    );
  }
}

class _ModeOptionTile extends StatelessWidget {
  const _ModeOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final BusinessMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      mode.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
