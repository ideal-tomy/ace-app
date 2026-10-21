import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/business_mode.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/person_option.dart';
import 'business_mode_badge.dart';
import 'check_billing_utils.dart';
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
    this.layout = PersonPickerLayout.standard,
    this.checkRepository,
  }) : assert(
         layout != PersonPickerLayout.staff || checkRepository != null,
         'PersonPickerLayout.staff requires checkRepository',
       );

  final List<PersonOption> people;
  final ValueChanged<PersonOption> onPersonSelected;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showSearch;
  final EdgeInsets padding;

  /// [PersonPickerLayout.staff] では [checkRepository] が必須（合計金額の算出用）。
  final PersonPickerLayout layout;
  final CheckRepository? checkRepository;

  @override
  State<PersonPickerList> createState() => _PersonPickerListState();
}

enum PersonPickerLayout {
  /// 注文フロー向け（アバター・入店時刻）。
  standard,

  /// 会計ページ向け（ホーム一覧に近いコンパクト表示）。
  staff,
}

class _PersonPickerListState extends State<PersonPickerList> {
  static final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final theme = Theme.of(context).textTheme;
                    final scaler = MediaQuery.textScalerOf(context);
                    double lineHeight(TextStyle? style) {
                      final painter = TextPainter(
                        text: TextSpan(text: 'あAg', style: style),
                        textDirection: Directionality.of(context),
                        textScaler: scaler,
                      )..layout();
                      final height = painter.height;
                      painter.dispose();
                      return height;
                    }

                    final columnWidth =
                        (constraints.maxWidth - widget.padding.horizontal - 8) /
                        2;
                    final columns = columnWidth >= 124 * scaler.scale(14) / 14
                        ? 2
                        : 1;
                    final staffLayout =
                        widget.layout == PersonPickerLayout.staff;
                    final height = staffLayout
                        ? (10 +
                                _StaffPersonCard.cardTopInset +
                                6 +
                                math.max(24, lineHeight(theme.titleLarge)) +
                                _StaffPersonCard.cardRowGap +
                                math.max(26, lineHeight(theme.titleMedium)) +
                                _StaffPersonCard.cardRowGap +
                                8)
                            .ceilToDouble()
                        : (8 +
                                20 +
                                math.max(28, lineHeight(theme.titleSmall)) +
                                6 +
                                lineHeight(theme.labelSmall) +
                                8 +
                                2 +
                                lineHeight(theme.bodySmall) +
                                8)
                            .ceilToDouble();
                    return GridView.builder(
                      padding: widget.padding,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: height,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        if (staffLayout) {
                          return _StaffPersonCard(
                            person: person,
                            checkRepository: widget.checkRepository!,
                            currency: _currency,
                            onTap: () => widget.onPersonSelected(person),
                          );
                        }
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
                                              ? person
                                                    .displayName
                                                    .characters
                                                    .first
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
                                      const SizedBox(width: 4),
                                      Text(
                                        '${person.peopleCount}名',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _ModeBadge(person: person),
                                  const SizedBox(height: 2),
                                  Text(
                                    '入店 ${DateFormat('HH:mm').format(person.createdAt)}',
                                    maxLines: 1,
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}

CheckSummary _summaryFromPerson(PersonOption person) {
  return CheckSummary(
    id: person.openCheckId,
    customerId: person.customerId,
    customerNameSnapshot: person.displayName,
    peopleCount: person.peopleCount,
    billingMode: person.billingMode,
    status: 'open',
    totalTaxIncluded: person.totalTaxIncluded,
    taxAmount: 0,
    createdAt: person.createdAt,
    switchedFromEvent: person.switchedFromEvent,
    nomihodaiStartedAt: person.nomihodaiStartedAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            person.nomihodaiStartedAtMillis!,
          ),
  );
}

class _StaffPersonCard extends StatelessWidget {
  const _StaffPersonCard({
    required this.person,
    required this.checkRepository,
    required this.currency,
    required this.onTap,
  });

  final PersonOption person;
  final CheckRepository checkRepository;
  final NumberFormat currency;
  final VoidCallback onTap;

  static const _nameStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const _amountStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const cardRowGap = 6.0;
  static const _badgeHeight = 30.0;
  static const cardTopInset = _badgeHeight + cardRowGap;

  @override
  Widget build(BuildContext context) {
    final summary = _summaryFromPerson(person);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            clipBehavior: Clip.none,
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  cardTopInset,
                  12,
                  cardRowGap,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _nameStyle,
                          ),
                        ),
                        Text('${person.peopleCount}名', style: _nameStyle),
                      ],
                    ),
                    const SizedBox(height: cardRowGap),
                    StreamBuilder<List<CheckItem>>(
                      stream: checkRepository.streamCheckItems(
                        person.openCheckId,
                      ),
                      builder: (context, snap) {
                        final items = snap.data ?? const <CheckItem>[];
                        final total = checkDisplayTotal(
                          summary: summary,
                          items: items,
                        );
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currency.format(total),
                              style: _amountStyle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: 10,
            child: BusinessModeBadge(
              label: person.modeBadgeLabel,
              billingMode: person.billingMode,
              switchedFromEvent: person.switchedFromEvent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.person});

  final PersonOption person;

  @override
  Widget build(BuildContext context) {
    final frame = BusinessModeBadgeColors.frameColor(
      billingMode: person.billingMode,
      switchedFromEvent: person.switchedFromEvent,
    );
    final text = BusinessModeBadgeColors.textColor(
      billingMode: person.billingMode,
      switchedFromEvent: person.switchedFromEvent,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: frame.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: frame.withValues(alpha: 0.35)),
      ),
      child: Text(
        person.modeBadgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
