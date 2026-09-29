import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_parent_validator.dart';

void main() {
  const validator = TrailParentValidator();
  final quest = Quest(
    id: 'quest-a',
    title: 'シンガポールへ行く',
    description: '旅行を実現する',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
  );
  final mission = Mission(
    id: 'mission-a',
    questId: 'quest-a',
    questTitle: quest.title,
    title: '旅行日程を決める',
    description: '候補月を決める',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.easy,
    status: MissionStatus.todo,
  );
  final task = QuestraTask(
    id: 'task-a',
    questId: 'quest-a',
    missionId: 'mission-a',
    questTitle: quest.title,
    missionTitle: mission.title,
    title: '候補月を相談する',
    action: '家族と候補月を相談する',
    doneCondition: '候補月を一つ記録する',
  );

  test('matching Quest Mission and Task hierarchy is valid', () {
    final result = validator.validate(
      parent: TrailParentContext(
        questId: quest.id,
        questTitle: quest.title,
        missionId: mission.id,
        missionTitle: mission.title,
        taskId: task.id,
        taskTitle: task.title,
      ),
      quests: [quest],
      missions: [mission],
      tasks: [task],
    );
    expect(result.status, TrailParentValidationStatus.valid);
  });

  test('cross-Quest Mission is rejected before persistence', () {
    final result = validator.validate(
      parent: TrailParentContext(
        questId: quest.id,
        questTitle: quest.title,
        missionId: 'mission-other',
        missionTitle: '別のMission',
      ),
      quests: [quest],
      missions: [
        Mission(
          id: 'mission-other',
          questId: 'quest-other',
          questTitle: '別のQuest',
          title: '別のMission',
          description: '別の航路',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.todo,
        ),
      ],
      tasks: const [],
    );
    expect(result.status, TrailParentValidationStatus.invalid);
  });

  test('removed Mission and archived Quest are rejected', () {
    final removed = mission.copyWith(routeState: MissionRouteState.removed);
    final removedResult = validator.validate(
      parent: TrailParentContext(
        questId: quest.id,
        questTitle: quest.title,
        missionId: removed.id,
        missionTitle: removed.title,
      ),
      quests: [quest],
      missions: [removed],
      tasks: const [],
    );
    final archivedResult = validator.validate(
      parent: TrailParentContext(
        questId: quest.id,
        questTitle: quest.title,
        missionId: mission.id,
        missionTitle: mission.title,
      ),
      quests: [quest.copyWith(status: QuestStatus.archived)],
      missions: [mission],
      tasks: const [],
    );
    expect(removedResult.status, TrailParentValidationStatus.invalid);
    expect(archivedResult.status, TrailParentValidationStatus.invalid);
  });

  test('empty local context is unresolved and left to the server boundary', () {
    const parent = TrailParentContext(
      questId: 'quest-a',
      questTitle: 'Quest',
      missionId: 'mission-a',
      missionTitle: 'Mission',
    );
    final result = validator.validate(
      parent: parent,
      quests: const [],
      missions: const [],
      tasks: const [],
    );
    expect(result.status, TrailParentValidationStatus.unresolved);
    expect(result.canProceed, isTrue);
  });
}
