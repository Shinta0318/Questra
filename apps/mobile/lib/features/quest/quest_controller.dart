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
        targetDate: DateTime.now().add(const Duration(days: 7)),
      ),
      Quest(
        title: 'Invite first guild member',
        description: 'Prepare the first lightweight guild loop.',
        difficulty: QuestDifficulty.easy,
        status: QuestStatus.draft,
        visibility: QuestVisibility.guild,
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
