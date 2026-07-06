import 'package:flutter/material.dart';

import '../../models/person_option.dart';

/// 来店中の対象者を2カラムで選ぶ（多人数でも縦長になりにくい）。
class PersonPickerList extends StatefulWidget {
  const PersonPickerList({
    super.key,
    required this.people,
    required this.onPersonSelected,
    this.emptyTitle = '来店中のお客様がいません',
    this.emptySubtitle = 'ホーム画面の「来店登録」で先に登録してください',
    this.showSearch = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<PersonOption> people;
  final ValueChanged<PersonOption> onPersonSelected;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showSearch;
  final EdgeInsets padding;

  @override
  State<PersonPickerList> createState() => _PersonPickerListState();
}

class _PersonPickerListState extends State<PersonPickerList> {
  String _keyword = '';

  List<PersonOption> get _filtered => widget.people
      .where(
        (p) => p.displayName.toLowerCase().contains(_keyword.toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    if (widget.people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                widget.emptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.emptySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearch) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.padding.left,
              0,
              widget.padding.right,
              8,
            ),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '名前で検索',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _keyword = value),
            ),
          ),
        ],
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '「$_keyword」に一致する来店者がいません',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  padding: widget.padding,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final person = filtered[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => widget.onPersonSelected(person),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                child: Text(
                                  person.displayName.isNotEmpty
                                      ? person.displayName.characters.first
                                      : '?',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  person.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
