import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/billing_rules.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/check_summary.dart';

/// 会計済み伝票の来店記録（入店・会計・退店）を表示し、退店時刻を事後修正する。
Future<void> showCheckVisitDetailSheet(
  BuildContext context, {
  required String checkId,
  CheckRepository? checkRepository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CheckVisitDetailSheet(
      checkId: checkId,
      checkRepository: checkRepository ?? CheckRepository(),
    ),
  );
}

class _CheckVisitDetailSheet extends StatefulWidget {
  const _CheckVisitDetailSheet({
    required this.checkId,
    required this.checkRepository,
  });

  final String checkId;
  final CheckRepository checkRepository;

  @override
  State<_CheckVisitDetailSheet> createState() => _CheckVisitDetailSheetState();
}

class _CheckVisitDetailSheetState extends State<_CheckVisitDetailSheet> {
  static final _dateTime = DateFormat('yyyy/MM/dd HH:mm');
  final _currency = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  bool _saving = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editDepartedAt(CheckSummary summary) async {
    final initial = summary.departedAt ?? summary.closedAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(
        summary.createdAt.year,
        summary.createdAt.month,
        summary.createdAt.day,
      ),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isBefore(summary.createdAt)) {
      _showMessage('退店時刻は入店時刻（${_dateTime.format(summary.createdAt)}）より後にしてください');
      return;
    }
    if (picked.isAfter(DateTime.now())) {
      _showMessage('未来の時刻は指定できません');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退店時刻を修正'),
        content: Text(
          '${summary.departedAt == null ? '未記録' : _dateTime.format(summary.departedAt!)}'
          ' → ${_dateTime.format(picked)}\n'
          '滞在 ${formatStayDuration(picked.difference(summary.createdAt))}\n\n'
          '確定済みの会計金額は変わりません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('修正する'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.checkRepository.updateDepartedAt(
        checkId: summary.id,
        departedAt: picked,
        correctedBy: FirebaseAuth.instance.currentUser!.uid,
      );
      if (mounted) _showMessage('退店時刻を修正しました');
    } on StateError catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('修正に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CheckSummary?>(
      stream: widget.checkRepository.streamCheckSummary(widget.checkId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('読み込みエラー: ${snapshot.error}'));
        }
        final summary = snapshot.data;
        if (summary == null) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final departedAt = summary.departedAt;
        final billedMinutes = summary.billingBilledMinutesFinal;
        final adjustment = summary.timeChargeAdjustmentAmount ?? 0;
        final titleStyle = Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(summary.customerNameSnapshot, style: titleStyle),
            const SizedBox(height: 12),
            Text('入店: ${_dateTime.format(summary.createdAt)}'),
            if (summary.closedAt != null)
              Text('会計: ${_dateTime.format(summary.closedAt!)}'),
            Text(
              '退店: ${departedAt == null ? '未記録' : _dateTime.format(departedAt)}',
              style: titleStyle,
            ),
            if (departedAt != null)
              Text(
                '実際の滞在: '
                '${formatStayDuration(departedAt.difference(summary.createdAt))}',
              ),
            if (billedMinutes != null)
              Text(
                '会計対象時間: '
                '${formatStayDuration(Duration(minutes: billedMinutes))}',
              ),
            if (adjustment > 0)
              Text('時間調整: −${_currency.format(adjustment)}'),
            Text(
              '確定金額: ${_currency.format(summary.finalAmount ?? summary.totalTaxIncluded)}',
            ),
            const SizedBox(height: 16),
            if (summary.isPaid)
              FilledButton.icon(
                onPressed: _saving ? null : () => _editDepartedAt(summary),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.edit_calendar),
                label: Text(_saving ? '保存中…' : '退店時刻を修正'),
              ),
            const SizedBox(height: 8),
            Text(
              '退店時刻を直しても、確定済みの会計金額・会計対象時間は変わりません。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<VisitCorrection>>(
              stream: widget.checkRepository.streamVisitCorrections(
                summary.id,
              ),
              builder: (context, corrections) {
                final rows = corrections.data ?? const <VisitCorrection>[];
                if (rows.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '修正履歴',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final c in rows)
                      Text(
                        '${c.correctedAt == null ? '' : _dateTime.format(c.correctedAt!)}  '
                        '${c.fromAt == null ? '未記録' : _dateTime.format(c.fromAt!)}'
                        ' → ${_dateTime.format(c.toAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
