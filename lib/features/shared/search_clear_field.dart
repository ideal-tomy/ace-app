import 'package:flutter/material.dart';

/// 入力中だけ右端に「×」を出し、1タップで全消去できる検索欄。
class SearchClearField extends StatefulWidget {
  const SearchClearField({
    super.key,
    required this.labelText,
    required this.onChanged,
  });

  final String labelText;
  final ValueChanged<String> onChanged;

  @override
  State<SearchClearField> createState() => _SearchClearFieldState();
}

class _SearchClearFieldState extends State<SearchClearField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '検索をクリア',
                icon: const Icon(Icons.cancel),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _clear,
              ),
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
    );
  }
}
