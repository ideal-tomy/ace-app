import 'package:flutter/material.dart';

import '../../../data/repositories/check_repository.dart';
import '../../../models/person_option.dart';

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
        final people = snapshot.data!;
        if (people.isEmpty) {
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
                    '来店中のお客様がいません',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ホーム画面の「来店登録」で先に登録してください',
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

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: people.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final person = people[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPersonSelected(person),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          person.displayName.isNotEmpty
                              ? person.displayName.characters.first
                              : '?',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          person.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
