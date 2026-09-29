import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  test(
    'parent policy rejection returns actionable feedback without mutation',
    () async {
      final container = ProviderContainer(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          trailControllerProvider.overrideWith(_TrailFixture.new),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trailControllerProvider.notifier);
      final previous = container.read(trailControllerProvider).single;
      final invalid = previous.copyWithParent(
        questId: 'quest-a',
        missionId: 'mission-b',
      );

      final result = await controller.updateTrailWithResult(invalid);

      expect(result.status, TrailUpdateStatus.rejected);
      expect(result.message, contains('QuestとMissionを選び直してください'));
      expect(container.read(trailControllerProvider).single.questId, 'quest-a');
      expect(
        container.read(trailControllerProvider).single.missionId,
        'mission-a',
      );
    },
  );
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [_quest('quest-a'), _quest('quest-b')];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-a', 'quest-a'),
    _mission('mission-b', 'quest-b'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    Trail(
      id: 'trail-a',
      questId: 'quest-a',
      missionId: 'mission-a',
      title: 'Trail',
      summary: '記録',
      content: '記録',
      trailType: TrailType.missionRecord,
    ),
  ];
}

Quest _quest(String id) => Quest(
  id: id,
  title: id,
  description: id,
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission(String id, String questId) => Mission(
  id: id,
  questId: questId,
  questTitle: questId,
  title: id,
  description: id,
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.todo,
);
