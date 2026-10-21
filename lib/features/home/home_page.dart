import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/business_mode.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/check_item.dart';
import '../../models/check_summary.dart';
import '../../models/person_option.dart';
import '../admin/menu_edit_page.dart';
import '../admin/sales_summary_admin_page.dart';
import '../checkout/checkout_detail_sheet.dart';
import '../checkout/checkout_page.dart';
import '../order/open_order_flow.dart';
import '../order/order_page.dart';
import '../shared/check_billing_utils.dart';
import '../shared/search_clear_field.dart';
import '../visit/visit_register_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.checkRepository, this.adminAuthService});

  final CheckRepository? checkRepository;
  final AdminAuthService? adminAuthService;

  /// MaterialApp で `home` を使っているため、`'/'` と重複させないこと。
  static const routeName = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _checkRepository = widget.checkRepository ?? CheckRepository();
  late final _adminAuthService = widget.adminAuthService ?? AdminAuthService();
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  bool _canOperate = false;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _refreshAccessState();
  }

  Future<void> _refreshAccessState() async {
    final canOperate = await _adminAuthService.canAccessAccounting();
    if (mounted) setState(() => _canOperate = canOperate);
  }

  Future<void> _openVisitRegister() async {
    final result = await Navigator.pushNamed(
      context,
      VisitRegisterPage.routeName,
    );
    if (!mounted || result is! VisitRegisterResult) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${result.customerName} さんの伝票を作成しました')),
    );
    final person = PersonOption(
      customerId: '',
      displayName: result.customerName,
      openCheckId: result.checkId,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      billingMode: result.billingMode,
    );
    final orderResult = await openOrderFlow(context, preselectedPerson: person);
    if (!mounted) return;
    showOrderFlowResultSnackBar(context, orderResult);
  }

  Future<void> _openOrderFor(CheckSummary summary) async {
    final person = PersonOption(
      customerId: summary.customerId,
      displayName: summary.customerNameSnapshot,
      openCheckId: summary.id,
      createdAtMillis: summary.createdAt.millisecondsSinceEpoch,
      billingMode: summary.billingMode,
      switchedFromEvent: summary.switchedFromEvent,
      totalTaxIncluded: summary.totalTaxIncluded,
      peopleCount: summary.peopleCount,
      nomihodaiStartedAtMillis:
          summary.nomihodaiStartedAt?.millisecondsSinceEpoch,
    );
    final result = await openOrderFlow(context, preselectedPerson: person);
    if (!mounted) return;
    showOrderFlowResultSnackBar(context, result);
  }

  Future<void> _openCheckoutFor(CheckSummary summary) async {
    final person = PersonOption(
      customerId: summary.customerId,
      displayName: summary.customerNameSnapshot,
      openCheckId: summary.id,
      createdAtMillis: summary.createdAt.millisecondsSinceEpoch,
      billingMode: summary.billingMode,
      switchedFromEvent: summary.switchedFromEvent,
      totalTaxIncluded: summary.totalTaxIncluded,
      peopleCount: summary.peopleCount,
    );
    final finalized = await showCheckoutDetailSheet(
      context,
      person: person,
      checkRepository: _checkRepository,
      canOperate: _canOperate,
    );
    if (!mounted || !finalized) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${summary.customerNameSnapshot} さんの会計を確定しました')),
    );
  }

  Future<void> _openItemsFor(CheckSummary summary) async {
    final person = PersonOption(
      customerId: summary.customerId,
      displayName: summary.customerNameSnapshot,
      openCheckId: summary.id,
      createdAtMillis: summary.createdAt.millisecondsSinceEpoch,
      billingMode: summary.billingMode,
      switchedFromEvent: summary.switchedFromEvent,
    );
    await Navigator.pushNamed(context, OrderPage.routeName, arguments: person);
  }

  Future<void> _switchToNomihodai(CheckSummary summary) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投げ放題に切り替えますか？'),
        content: Text(
          '${summary.customerNameSnapshot} さん\n'
          'これから時間料金が始まります。これまでの注文はそのまま残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('切り替える'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _checkRepository.switchToNomihodai(summary.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${summary.customerNameSnapshot} さんを投げ放題に切り替えました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('切替に失敗しました: $e')));
    }
  }

  Future<void> _voidCheck(CheckSummary summary) async {
    final itemCount = await _checkRepository.countCheckItems(summary.id);
    final hasItems = itemCount > 0;
    if (!mounted) return;

    if (!hasItems) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('伝票を取り消しますか？'),
          content: Text('${summary.customerNameSnapshot} さんの空の伝票を取り消します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('取り消す'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await _doVoid(summary, reason: null);
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('明細がある伝票の取消'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${summary.customerNameSnapshot} さんには注文が残っています。'
              '取消するには名前を再入力してください。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '「${summary.customerNameSnapshot}」と入力',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim() != summary.customerNameSnapshot) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('名前が一致しません')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('取り消す'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    await _doVoid(summary, reason: '明細あり取消');
  }

  Future<void> _doVoid(CheckSummary summary, {String? reason}) async {
    try {
      await _checkRepository.voidCheck(checkId: summary.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${summary.customerNameSnapshot} さんの伝票を取り消しました'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('取消に失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('簡易会計アプリ'),
        actions: [
          IconButton(
            tooltip: '会計一覧',
            onPressed: () =>
                Navigator.pushNamed(context, CheckoutPage.routeName),
            icon: const Icon(Icons.receipt_long),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _navigationButton(
                          '来店登録',
                          Icons.person_add_alt_1,
                          _openVisitRegister,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _navigationButton(
                          '会計',
                          Icons.receipt_long,
                          () => Navigator.pushNamed(
                            context,
                            CheckoutPage.routeName,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _navigationButton(
                          '商品登録',
                          Icons.menu_book_outlined,
                          () => Navigator.pushNamed(
                            context,
                            MenuEditPage.routeName,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _navigationButton(
                          '日別売上',
                          Icons.bar_chart,
                          () => Navigator.pushNamed(
                            context,
                            SalesSummaryAdminPage.routeName,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchClearField(
                labelText: '未会計を名前で検索',
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '未会計のお客様',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CheckSummary>>(
                stream: _checkRepository.streamOpenChecks(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('取得エラー: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final checks = snapshot.data!
                      .where(
                        (c) => c.customerNameSnapshot.toLowerCase().contains(
                          _keyword.toLowerCase(),
                        ),
                      )
                      .toList();

                  if (checks.isEmpty) {
                    return Center(
                      child: Text(
                        _keyword.isEmpty
                            ? '未会計のお客様はいません\n「来店登録」から始めましょう'
                            : '「$_keyword」に一致する未会計はありません',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: checks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final summary = checks[index];
                      return _OpenCheckCard(
                        summary: summary,
                        checkRepository: _checkRepository,
                        currency: _currency,
                        onTap: () => _openOrderFor(summary),
                        onCheckout: () => _openCheckoutFor(summary),
                        onItems: () => _openItemsFor(summary),
                        onVoid: () => _voidCheck(summary),
                        onSwitch: summary.billingMode == BusinessMode.event
                            ? () => _switchToNomihodai(summary)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _navigationButton(String label, IconData icon, VoidCallback onPressed) {
  return FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    icon: Icon(icon, size: 20),
    label: Text(label, maxLines: 1),
  );
}

class _OpenCheckCard extends StatelessWidget {
  const _OpenCheckCard({
    required this.summary,
    required this.checkRepository,
    required this.currency,
    required this.onTap,
    required this.onCheckout,
    required this.onItems,
    required this.onVoid,
    this.onSwitch,
  });

  final CheckSummary summary;
  final CheckRepository checkRepository;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onCheckout;
  final VoidCallback onItems;
  final VoidCallback onVoid;
  final VoidCallback? onSwitch;

  static const _nameElapsedStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const _amountEntryStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// バッジ下・行間・カード下で揃える縦のすき間。
  static const _cardRowGap = 6.0;

  /// 左上バッジ（labelLarge + 縦 padding 8）のおおよその高さ。
  static const _badgeHeight = 30.0;

  /// 1行目はバッジの直下から。バッジの Positioned(top: 0) は変えない。
  static const _cardTopInset = _badgeHeight + _cardRowGap;

  @override
  Widget build(BuildContext context) {
    final isNormal = summary.billingMode == BusinessMode.normal;
    final badgeColor = isNormal
        ? const Color(0xFF0F766E)
        : const Color(0xFFEA580C);

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
                  14,
                  _cardTopInset,
                  4,
                  _cardRowGap,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  summary.customerNameSnapshot,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _nameElapsedStyle,
                                ),
                              ),
                              Text(
                                '${summary.peopleCount}名',
                                style: _nameElapsedStyle,
                              ),
                            ],
                          ),
                          const SizedBox(height: _cardRowGap),
                          StreamBuilder<List<CheckItem>>(
                            stream: checkRepository.streamCheckItems(
                              summary.id,
                            ),
                            builder: (context, snap) {
                              final items = snap.data ?? const <CheckItem>[];
                              final total = checkDisplayTotal(
                                summary: summary,
                                items: items,
                              );
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currency.format(total),
                                  style: _amountEntryStyle,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: _StayClock(
                        createdAt: summary.createdAt,
                        elapsedStyle: _nameElapsedStyle,
                        entryStyle: _amountEntryStyle,
                      ),
                    ),
                    PopupMenuButton<_CheckAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _CheckAction.order:
                            onTap();
                          case _CheckAction.checkout:
                            onCheckout();
                          case _CheckAction.items:
                            onItems();
                          case _CheckAction.switchMode:
                            onSwitch?.call();
                          case _CheckAction.voidCheck:
                            onVoid();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _CheckAction.order,
                          child: Text('注文を追加'),
                        ),
                        const PopupMenuItem(
                          value: _CheckAction.checkout,
                          child: Text('会計'),
                        ),
                        const PopupMenuItem(
                          value: _CheckAction.items,
                          child: Text('明細を確認'),
                        ),
                        if (onSwitch != null)
                          const PopupMenuItem(
                            value: _CheckAction.switchMode,
                            child: Text('投げ放題に切替'),
                          ),
                        const PopupMenuItem(
                          value: _CheckAction.voidCheck,
                          child: Text('伝票を取消'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  badgeColor.withValues(alpha: 0.14),
                  Theme.of(context).colorScheme.surface,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                summary.modeBadgeLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CheckAction { order, checkout, items, switchMode, voidCheck }

/// 滞在時間と入店時刻。明細の StreamBuilder を作り直さないよう、ここだけ毎秒再描画する。
class _StayClock extends StatefulWidget {
  const _StayClock({
    required this.createdAt,
    required this.elapsedStyle,
    required this.entryStyle,
  });

  final DateTime createdAt;
  final TextStyle elapsedStyle;
  final TextStyle entryStyle;

  @override
  State<_StayClock> createState() => _StayClockState();
}

class _StayClockState extends State<_StayClock> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final elapsed = DateTime.now().difference(widget.createdAt);
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    if (safe.inHours < 1) {
      final sec = safe.inSeconds % 60;
      return '${safe.inMinutes}分${sec.toString().padLeft(2, '0')}秒';
    }
    final hours = safe.inHours;
    final rem = safe.inMinutes % 60;
    return rem == 0 ? '$hours時間' : '$hours時間$rem分';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('経過 $_elapsedLabel', style: widget.elapsedStyle),
        ),
        const SizedBox(height: _OpenCheckCard._cardRowGap),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '入店 ', style: TextStyle(fontSize: 12)),
                TextSpan(text: DateFormat('HH:mm').format(widget.createdAt)),
              ],
            ),
            style: widget.entryStyle,
          ),
        ),
      ],
    );
  }
}
