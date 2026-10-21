import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/admin_auth_service.dart';
import '../../core/business_day.dart';
import '../../core/business_mode.dart';
import '../../core/csv_download.dart';
import '../../core/payment_method.dart';
import '../../data/repositories/sales_summary_repository.dart';
import '../../models/check_summary.dart';
import '../../models/daily_closing.dart';
import '../checkout/check_visit_detail_sheet.dart';

enum _SalesModeFilter { all, event, normal }

class SalesSummaryAdminPage extends StatefulWidget {
  const SalesSummaryAdminPage({super.key});

  static const routeName = '/admin/sales-summary';

  @override
  State<SalesSummaryAdminPage> createState() =>
      _SalesSummaryAdminPageState();
}

class _SalesSummaryAdminPageState extends State<SalesSummaryAdminPage> {
  final _auth = AdminAuthService();
  final _repo = SalesSummaryRepository();
  late DateTime _selectedBusinessDate;
  _SalesModeFilter _mode = _SalesModeFilter.all;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _selectedBusinessDate = businessDateFor(DateTime.now());
  }

  String get _selectedKey => businessDateKey(_selectedBusinessDate);

  Future<void> _selectDate() async {
    final jstDate = _selectedBusinessDate.toUtc().add(
      const Duration(hours: 9),
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(jstDate.year, jstDate.month, jstDate.day),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedBusinessDate = businessDateFromCalendarDate(selected);
    });
  }

  List<CheckSummary> _checksForSelectedDay(List<CheckSummary> checks) {
    return checks
        .where(
          (check) =>
              businessDateKey(_repo.effectiveBusinessDate(check)) ==
              _selectedKey,
        )
        .toList();
  }

  List<CheckSummary> _modeFiltered(List<CheckSummary> checks) {
    return checks.where((check) {
      return switch (_mode) {
        _SalesModeFilter.all => true,
        // 切替伝票は両方のフィルタに出す（金額は各按分）。
        _SalesModeFilter.event =>
          _repo.eventAmountOf(check) > 0 ||
              (check.billingMode == BusinessMode.event &&
                  !check.switchedFromEvent),
        _SalesModeFilter.normal =>
          _repo.normalAmountOf(check) > 0 ||
              check.billingMode == BusinessMode.normal,
      };
    }).toList();
  }

  Future<void> _closeDay({
    required List<CheckSummary> paidChecks,
    required int openCount,
  }) async {
    if (_closing || openCount > 0 || paidChecks.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$_selectedKey の営業日を締めますか？'),
        content: Text(
          '会計済み ${paidChecks.length}件を確定保存します。締め後はこの画面から変更できません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('日次締めを確定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      await _repo.closeBusinessDay(
        businessDate: _selectedBusinessDate,
        paidChecks: paidChecks,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_selectedKey の日次締めを保存しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('日次締めに失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  static String _csvCell(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _downloadSummaryCsv(DailyClosing closing) {
    if (!_ensureWebCsv()) return;
    final csv = StringBuffer()
      ..writeln(
        'businessDate,totalSales,eventSales,normalSales,checkCount,'
        'eventCheckCount,normalCheckCount,guestCount,eventGuestCount,'
        'normalGuestCount,closedAt,closedBy',
      )
      ..writeln(
        [
          closing.businessDateKey,
          closing.totalSales,
          closing.eventSales,
          closing.normalSales,
          closing.checkCount,
          closing.eventCheckCount,
          closing.normalCheckCount,
          closing.guestCount,
          closing.eventGuestCount,
          closing.normalGuestCount,
          closing.closedAt?.toUtc().toIso8601String() ?? '',
          _csvCell(closing.closedBy),
        ].join(','),
      );
    downloadCsvUtf8Bom(
      filename: 'daily_summary_${closing.businessDateKey}.csv',
      csvBody: csv.toString(),
    );
  }

  void _downloadChecksCsv(
    DailyClosing closing,
    List<DailyClosingCheck> checks,
  ) {
    if (!_ensureWebCsv()) return;
    final csv = StringBuffer()
      ..writeln(
        'businessDate,billingMode,checkId,customerName,peopleCount,'
        'finalAmount,eventAmount,normalAmount,paymentMethod,taxAmount,closedAt',
      );
    for (final check in checks) {
      csv.writeln(
        [
          closing.businessDateKey,
          check.billingMode.firestoreValue,
          _csvCell(check.id),
          _csvCell(check.customerName),
          check.peopleCount,
          check.finalAmount,
          check.eventAmount ?? '',
          check.normalAmount ?? '',
          check.paymentMethod?.firestoreValue ?? '',
          check.taxAmount,
          check.closedAt.toUtc().toIso8601String(),
        ].join(','),
      );
    }
    downloadCsvUtf8Bom(
      filename: 'daily_checks_${closing.businessDateKey}.csv',
      csvBody: csv.toString(),
    );
  }

  bool _ensureWebCsv() {
    if (kIsWeb) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSVダウンロードはWeb版のみ対応しています')),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _auth.isCurrentUserAdmin(),
      builder: (context, adminSnapshot) {
        if (!adminSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (adminSnapshot.data != true) {
          return const Scaffold(
            body: Center(child: Text('売上集計は管理者のみ確認できます')),
          );
        }
        return _buildPage();
      },
    );
  }

  Widget _buildPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('日別売上集計・日次締め')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<CheckSummary>>(
            stream: _repo.streamAllChecks(),
            builder: (context, checksSnapshot) {
              if (checksSnapshot.hasError) {
                return Center(
                  child: Text('売上取得エラー: ${checksSnapshot.error}'),
                );
              }
              if (!checksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final dayChecks = _checksForSelectedDay(checksSnapshot.data!);
              final paidChecks = dayChecks
                  .where((check) => check.status == 'paid')
                  .toList();
              final openChecks = dayChecks
                  .where((check) => check.status == 'open')
                  .toList();
              return StreamBuilder<DailyClosing?>(
                stream: _repo.streamDailyClosing(_selectedKey),
                builder: (context, closingSnapshot) {
                  if (closingSnapshot.hasError) {
                    return Center(
                      child: Text('締めデータ取得エラー: ${closingSnapshot.error}'),
                    );
                  }
                  final closing = closingSnapshot.data;
                  if (closing == null) {
                    return _buildContent(
                      paidChecks: paidChecks,
                      openChecks: openChecks,
                      closing: null,
                      closingChecks: const [],
                    );
                  }
                  return StreamBuilder<List<DailyClosingCheck>>(
                    stream: _repo.streamClosingChecks(_selectedKey),
                    builder: (context, snapshots) {
                      if (snapshots.hasError) {
                        return Center(
                          child: Text('締め明細取得エラー: ${snapshots.error}'),
                        );
                      }
                      return _buildContent(
                        paidChecks: paidChecks,
                        openChecks: openChecks,
                        closing: closing,
                        closingChecks: snapshots.data ?? const [],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required List<CheckSummary> paidChecks,
    required List<CheckSummary> openChecks,
    required DailyClosing? closing,
    required List<DailyClosingCheck> closingChecks,
  }) {
    final currency = NumberFormat.currency(
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
    );
    int amountOf(CheckSummary row) {
      return switch (_mode) {
        _SalesModeFilter.all => _repo.amountOf(row),
        _SalesModeFilter.event => _repo.eventAmountOf(row),
        _SalesModeFilter.normal => _repo.normalAmountOf(row),
      };
    }
    final displayed = _modeFiltered(paidChecks);
    final sales = displayed.fold<int>(0, (sum, row) => sum + amountOf(row));
    // 人数・件数は最終モード基準（切替は通常側）。イベント/通常フィルタでは
    // 按分金額がある伝票を表示するが、人数は重複しないよう最終モードで数える。
    final guests = displayed.fold<int>(0, (sum, row) {
      return switch (_mode) {
        _SalesModeFilter.all => sum + row.peopleCount,
        _SalesModeFilter.event =>
          row.billingMode == BusinessMode.event && !row.switchedFromEvent
              ? sum + row.peopleCount
              : sum,
        _SalesModeFilter.normal =>
          row.billingMode == BusinessMode.normal
              ? sum + row.peopleCount
              : sum,
      };
    });
    final eventSales = paidChecks.fold<int>(
      0,
      (sum, row) => sum + _repo.eventAmountOf(row),
    );
    final normalSales = paidChecks.fold<int>(
      0,
      (sum, row) => sum + _repo.normalAmountOf(row),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _closing ? null : _selectDate,
          icon: const Icon(Icons.calendar_month),
          label: Text('$_selectedKey 営業日（翌6:00切替）'),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_SalesModeFilter>(
          segments: const [
            ButtonSegment(value: _SalesModeFilter.all, label: Text('すべて')),
            ButtonSegment(
              value: _SalesModeFilter.event,
              label: Text('イベント'),
            ),
            ButtonSegment(
              value: _SalesModeFilter.normal,
              label: Text('通常営業'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('合計 ${currency.format(sales)}'),
                Text('イベント ${currency.format(eventSales)}'),
                Text('通常営業 ${currency.format(normalSales)}'),
                Text('会計済み ${displayed.length}件'),
                Text('人数 $guests名'),
                Text(
                  '客単価 ${currency.format(guests == 0 ? 0 : sales ~/ guests)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: openChecks.isEmpty
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(
              openChecks.isEmpty ? Icons.check_circle : Icons.warning_amber,
            ),
            title: Text('未会計 ${openChecks.length}件'),
            subtitle: Text(
              openChecks.isEmpty
                  ? '日次締めを実行できます'
                  : '未会計伝票をすべて会計してから日次締めしてください',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (closing == null)
          FilledButton.icon(
            onPressed: openChecks.isEmpty && paidChecks.isNotEmpty && !_closing
                ? () => _closeDay(
                    paidChecks: paidChecks,
                    openCount: openChecks.length,
                  )
                : null,
            icon: const Icon(Icons.lock),
            label: Text(_closing ? '日次締め保存中...' : 'この営業日を締める'),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '日次締め済み・${currency.format(closing.totalSales)}・'
                    '${closing.checkCount}件',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _downloadSummaryCsv(closing),
                        icon: const Icon(Icons.download),
                        label: const Text('サマリーCSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: closingChecks.length == closing.checkCount
                            ? () => _downloadChecksCsv(closing, closingChecks)
                            : null,
                        icon: const Icon(Icons.download),
                        label: Text(
                          '伝票明細CSV (${closingChecks.length}/${closing.checkCount})',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: displayed.isEmpty
              ? const Center(child: Text('この営業日の会計済み伝票はありません'))
              : ListView.separated(
                  itemCount: displayed.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = displayed[index];
                    final adjustment = row.timeChargeAdjustmentAmount ?? 0;
                    return ListTile(
                      title: Text(row.customerNameSnapshot),
                      subtitle: Text(
                        '${row.modeBadgeLabel}・${row.peopleCount}名・'
                        '${row.paymentMethod?.label ?? '支払未記録'}・'
                        '${row.closedAt == null ? '会計時刻不明' : DateFormat('HH:mm').format(row.closedAt!.toLocal())}'
                        '${adjustment > 0 ? '・時間調整 −${currency.format(adjustment)}' : ''}',
                      ),
                      trailing: Text(currency.format(amountOf(row))),
                      onTap: () =>
                          showCheckVisitDetailSheet(context, checkId: row.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
