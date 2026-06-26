import 'package:flutter/material.dart';

class CustomFoodOrderForm {
  const CustomFoodOrderForm({
    required this.name,
    required this.priceTaxIncluded,
  });

  final String name;
  final int priceTaxIncluded;
}

class CustomGoodsOrderForm {
  const CustomGoodsOrderForm({
    required this.name,
    required this.priceTaxIncluded,
  });

  final String name;
  final int priceTaxIncluded;
}

class CustomFoodOrderDialog extends StatefulWidget {
  const CustomFoodOrderDialog({super.key});

  @override
  State<CustomFoodOrderDialog> createState() => _CustomFoodOrderDialogState();
}

class _CustomFoodOrderDialogState extends State<CustomFoodOrderDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = int.tryParse(
      _priceController.text.trim().replaceAll(',', ''),
    );
    if (name.isEmpty) {
      setState(() => _error = 'フード名を入力してください');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = '金額を正しく入力してください');
      return;
    }
    Navigator.pop(
      context,
      CustomFoodOrderForm(name: name, priceTaxIncluded: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('フード追加'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'オーダー名',
                hintText: '例）本日のおすすめ',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '金額（税込）',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('選択')),
      ],
    );
  }
}

class CustomGoodsOrderDialog extends StatefulWidget {
  const CustomGoodsOrderDialog({super.key});

  @override
  State<CustomGoodsOrderDialog> createState() => _CustomGoodsOrderDialogState();
}

class _CustomGoodsOrderDialogState extends State<CustomGoodsOrderDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final price = int.tryParse(
      _priceController.text.trim().replaceAll(',', ''),
    );
    if (name.isEmpty) {
      setState(() => _error = '商品名を入力してください');
      return;
    }
    if (price == null || price < 0) {
      setState(() => _error = '金額を正しく入力してください');
      return;
    }
    Navigator.pop(
      context,
      CustomGoodsOrderForm(name: name, priceTaxIncluded: price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('グッズ販売追加'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '商品名',
                hintText: '例）Tシャツ、バレル',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: '金額（税込）',
                prefixText: '¥',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('選択')),
      ],
    );
  }
}
