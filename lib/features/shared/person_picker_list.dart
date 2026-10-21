import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/business_mode.dart';
import '../../models/person_option.dart';
import 'search_clear_field.dart';

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
            child: SearchClearField(
              labelText: '名前で検索',
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
                    childAspectRatio: 1.9,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    child: Text(
                                      person.displayName.isNotEmpty
                                          ? person.displayName.characters.first
                                          : '?',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      person.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _ModeBadge(person: person),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('HH:mm').format(person.createdAt),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
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

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.person});

  final PersonOption person;

  @override
  Widget build(BuildContext context) {
    final isNormal = person.billingMode == BusinessMode.normal;
    final color = isNormal
        ? const Color(0xFF0F766E)
        : const Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        person.modeBadgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
