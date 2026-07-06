import 'package:flutter/material.dart';

import '../../../data/repositories/check_repository.dart';
import '../../../models/person_option.dart';
import '../../shared/person_picker_list.dart';

class OrderPersonStep extends StatelessWidget {
  const OrderPersonStep({
    super.key,
    required this.checkRepository,
    required this.onPersonSelected,
  });

  final CheckRepository checkRepository;
  final ValueChanged<PersonOption> onPersonSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonOption>>(
      stream: checkRepository.streamOpenPeople(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('登録者取得エラー: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PersonPickerList(
          people: snapshot.data!,
          onPersonSelected: onPersonSelected,
        );
      },
    );
  }
}
