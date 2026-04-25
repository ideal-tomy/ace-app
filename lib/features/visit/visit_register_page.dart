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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前またはあだ名を入力してください')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _customerRepository.createCustomerIfNeeded(name);
      await _checkRepository.createOpenCheck(
        customerName: name,
        billingMode: BusinessModeState.notifier.value,
        peopleCount: _peopleCount,
      );
      if (mounted) {
        Navigator.pop(context, name);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登録に失敗しました: $error')),
        );
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
                      if (value.text.isEmpty) return const Iterable<String>.empty();
                      return names.where((n) =>
                          n.toLowerCase().contains(value.text.toLowerCase()));
                    },
                    onSelected: (value) => _controller.text = value,
                    fieldViewBuilder: (context, textController, focusNode, onSubmit) {
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
