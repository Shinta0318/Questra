import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  test(
    'Mission controller edits planning state and keeps one today Mission',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final quest = Quest(
        title: 'Launch',
        description: 'Ship the product',
        difficulty: QuestDifficulty.normal,
        status: QuestStatus.active,
        visibility: QuestVisibility.private,
      );
      final controller = container.read(missionControllerProvider.notifier);

      final first = controller.addMissionDraft(
        quest: quest,
        title: 'First',
        description: 'First step',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
        isToday: true,
      );
      final second = controller.addMissionDraft(
        quest: quest,
        title: 'Second',
        description: 'Second step',
        guideType: GuideType.training,
        difficulty: MissionDifficulty.easy,
        isToday: true,
      );

      var missions = container.read(missionControllerProvider);
      expect(missions.where((mission) => mission.isToday), hasLength(1));
      expect(missions.singleWhere((mission) => mission.isToday).id, second.id);

      controller.updateMission(second.copyWith(title: 'Edited'));
      controller.reorderForQuest(quest.id, 1, 0);
      missions = container.read(missionControllerProvider);
      expect(
        missions.singleWhere((mission) => mission.id == second.id).title,
        'Edited',
      );
      expect(
        missions.singleWhere((mission) => mission.id == second.id).sortOrder,
        0,
      );

      controller.removeMission(first.id);
      expect(
        container.read(missionControllerProvider).map((mission) => mission.id),
        isNot(contains(first.id)),
      );
    },
  );

  test('Mission completion synchronizes Quest progress', () {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(FixtureQuestController.new),
      ],
    );
    addTearDown(container.dispose);
    final quest = container.read(questControllerProvider).first;
    final controller = container.read(missionControllerProvider.notifier);
    final first = controller.addMissionDraft(
      quest: quest,
      title: 'First',
      description: '',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
    );
    controller.addMissionDraft(
      quest: quest,
      title: 'Second',
      description: '',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
    );

    expect(
      container
          .read(questControllerProvider)
          .singleWhere((item) => item.id == quest.id)
          .progress,
      0,
    );

    controller.completeMission(first.id);

    expect(
      container
          .read(questControllerProvider)
          .singleWhere((item) => item.id == quest.id)
          .progress,
      0.5,
    );
  });
}
