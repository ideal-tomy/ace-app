import 'package:flutter/material.dart';

import '../../models/person_option.dart';

class PersonSelector extends StatefulWidget {
  const PersonSelector({
    super.key,
    required this.people,
    required this.onSelected,
    this.label = '対象者',
    this.initialSelectedCheckId,
    this.showSearchField = true,
  });

  final List<PersonOption> people;
  final ValueChanged<PersonOption?> onSelected;
  final String label;
  final String? initialSelectedCheckId;
  final bool showSearchField;

  @override
  State<PersonSelector> createState() => _PersonSelectorState();
}

class _PersonSelectorState extends State<PersonSelector> {
  String _keyword = '';
  String? _selectedCheckId;
  bool _notifiedInitial = false;

  @override
  void initState() {
    super.initState();
    _selectedCheckId = widget.initialSelectedCheckId;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.people
        .where((p) => p.displayName.toLowerCase().contains(_keyword.toLowerCase()))
        .toList();

    if (_selectedCheckId == null && filtered.isNotEmpty) {
      _selectedCheckId = filtered.first.openCheckId;
    }

    final selectedPerson =
        filtered.where((p) => p.openCheckId == _selectedCheckId).firstOrNull;
    if (selectedPerson != null && !_notifiedInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelected(selectedPerson);
      });
      _notifiedInitial = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSearchField) ...[
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '名前で検索',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _keyword = value),
          ),
          const SizedBox(height: 12),
        ],
        Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Text('該当する来店者がいません')
        else
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final person = filtered[index];
                final selected = person.openCheckId == _selectedCheckId;
                return ChoiceChip(
                  label: Text(person.displayName),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedCheckId = person.openCheckId);
                    widget.onSelected(person);
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {
            setState(() => _selectedCheckId = null);
            widget.onSelected(null);
          },
          child: const Text('選択をクリア'),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
