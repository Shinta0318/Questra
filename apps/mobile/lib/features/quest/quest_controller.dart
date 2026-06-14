import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quest_model.dart';

final questControllerProvider = NotifierProvider<QuestController, List<Quest>>(
  QuestController.new,
);

class QuestController extends Notifier<List<Quest>> {
  @override
  List<Quest> build() {
    return [
      Quest(
        title: 'Design the first adventure arc',
        description: 'Shape the first Questra journey with Arc.',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        progress: 0.42,
        category: '世界観づくり',
        targetDate: DateTime.now().add(const Duration(days: 7)),
      ),
      Quest(
        title: 'Invite first guild member',
        description: 'Prepare the first lightweight guild loop.',
        difficulty: QuestDifficulty.easy,
        status: QuestStatus.draft,
        visibility: QuestVisibility.guild,
        progress: 0.16,
        category: 'コミュニティ',
      ),
      Quest(
        title: 'Build a morning training ritual',
        description: 'Create a small repeatable routine for real progress.',
        difficulty: QuestDifficulty.hard,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
        progress: 0.68,
        category: 'トレーニング',
      ),
    ];
  }

  Quest? findById(String id) {
    for (final quest in state) {
      if (quest.id == id) {
        return quest;
      }
    }
    return null;
  }

  void add(Quest quest) {
    state = [...state, quest];
  }

  void update(Quest updatedQuest) {
    state = [
      for (final quest in state)
        if (quest.id == updatedQuest.id) updatedQuest else quest,
    ];
  }

  void remove(String id) {
    state = state.where((quest) => quest.id != id).toList();
  }
}
