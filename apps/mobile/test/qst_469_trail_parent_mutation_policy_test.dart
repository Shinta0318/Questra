import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_parent_validator.dart';

void main() {
  const policy = TrailParentMutationPolicy();
  final questA = _quest('quest-a');
  final questB = _quest('quest-b');
  final missionA = _mission('mission-a', questA);
  final missionB = _mission('mission-b', questB);

  test('content edits keep an existing parent unchanged', () {
    final previous = _trail(
      id: 'trail-a',
      questId: questA.id,
      missionId: missionA.id,
    );
    final updated = previous.copyWith(content: '更新した内容');
    expect(
      policy.canApply(
        previous: previous,
        updated: updated,
        quests: const [],
        missions: const [],
        tasks: const [],
      ),
      isTrue,
    );
  });

  test('a manual Trail can move only to a resolved valid hierarchy', () {
    final previous = _trail(
      id: 'trail-a',
      questId: questA.id,
      missionId: missionA.id,
    );
    final updated = previous.copyWithParent(
      questId: questB.id,
      missionId: missionB.id,
    );
    expect(
      policy.canApply(
        previous: previous,
        updated: updated,
        quests: [questA, questB],
        missions: [missionA, missionB],
        tasks: const [],
      ),
      isTrue,
    );
    expect(
      policy.canApply(
        previous: previous,
        updated: updated,
        quests: [questA],
        missions: [missionA],
        tasks: const [],
      ),
      isFalse,
    );
  });

  test('Task-linked Trail parent is immutable', () {
    final task = QuestraTask(
      id: 'task-a',
      questId: questA.id,
      missionId: missionA.id,
      title: 'Task',
      action: '実行する',
      doneCondition: '完了を確認する',
    );
    final previous = Trail(
      id: 'trail-task',
      questId: questA.id,
      missionId: missionA.id,
      taskId: task.id,
      title: 'Task Trail',
      summary: '記録',
      content: '記録',
      trailType: TrailType.missionRecord,
    );
    final updated = previous.copyWithParent(
      questId: questB.id,
      missionId: missionB.id,
    );
    expect(
      policy.canApply(
        previous: previous,
        updated: updated,
        quests: [questA, questB],
        missions: [missionA, missionB],
        tasks: [task],
      ),
      isFalse,
    );
  });
}

Quest _quest(String id) => Quest(
  id: id,
  title: id,
  description: id,
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission(String id, Quest quest) => Mission(
  id: id,
  questId: quest.id,
  questTitle: quest.title,
  title: id,
  description: id,
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.todo,
);

Trail _trail({
  required String id,
  required String questId,
  required String missionId,
}) => Trail(
  id: id,
  questId: questId,
  missionId: missionId,
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
);
