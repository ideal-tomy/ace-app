import 'package:flutter/material.dart';

import '../../core/admin_auth_service.dart';
import '../../data/repositories/check_repository.dart';
import '../../models/person_option.dart';
import '../shared/person_picker_list.dart';
import 'checkout_detail_sheet.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  static const routeName = '/checkout';

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _checkRepository = CheckRepository();
  final _adminAuthService = AdminAuthService();
  bool _canOperate = false;

  Future<void> _refreshAccessState() async {
    final canOperate = await _adminAuthService.isCurrentUserAdmin();
    if (mounted) setState(() => _canOperate = canOperate);
  }

  Future<void> _openCheckoutSheet(PersonOption person) async {
    final finalized = await showCheckoutDetailSheet(
      context,
      person: person,
      checkRepository: _checkRepository,
      canOperate: _canOperate,
    );
    if (!mounted || !finalized) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(content: Text('${person.displayName} さんの会計を確定しました')),
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshAccessState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会計')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '会計は伝票の営業モード（来店登録時）に基づいて計算されます',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '会計する人を選んでください',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<PersonOption>>(
                stream: _checkRepository.streamOpenPeople(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('会計対象取得エラー: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return PersonPickerList(
                    people: snapshot.data!,
                    emptyTitle: '会計対象のお客様がいません',
                    emptySubtitle: '来店登録済みで未会計の方がここに表示されます',
                    onPersonSelected: _openCheckoutSheet,
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
