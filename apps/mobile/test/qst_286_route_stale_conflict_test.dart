import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/route_snapshot_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  final quest = Quest(
    id: 'quest-1',
    title: '富士山に登る',
    description: '',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
    targetDate: DateTime(2027, 8),
  );
  final mission = Mission(
    id: 'mission-1',
    questId: quest.id,
    questTitle: quest.title,
    title: '装備を整える',
    description: '',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.normal,
    status: MissionStatus.todo,
  );
  final task = QuestraTask(
    id: 'task-1',
    questId: quest.id,
    missionId: mission.id,
    title: '登山靴を確認する',
    action: '手持ちの登山靴の状態を確認する',
    doneCondition: '状態を記録している',
    status: TaskStatus.inProgress,
  );

  test('提案後のTask完了をstale conflictとして検出する', () {
    const service = RouteSnapshotService();
    final before = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task],
    );
    final after = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task.copyWith(status: TaskStatus.completed)],
    );

    final conflict = service.compare(before, after);

    expect(conflict.isStale, isTrue);
    expect(conflict.changedEntityIds, contains('task:task-1'));
    expect(conflict.message, contains('最新の航路'));
  });

  test('順序が違うだけの同一スナップショットは競合にしない', () {
    const service = RouteSnapshotService();
    final secondTask = QuestraTask(
      id: 'task-2',
      questId: quest.id,
      missionId: mission.id,
      title: '装備表を作る',
      action: '必要装備を一覧にする',
      doneCondition: '装備表が保存されている',
    );
    final first = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task, secondTask],
    );
    final reordered = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [secondTask, task],
    );

    expect(service.compare(first, reordered).isStale, isFalse);
  });

  test('DB承認境界は行ロック後にfreshnessを再確認する', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final migration = File(
      '${root.path}/supabase/migrations/'
      '202608080006_route_proposal_stale_conflict_guard.sql',
    ).readAsStringSync();

    expect(migration, contains("status = 'stale'"));
    expect(migration, contains('base_snapshot'));
    expect(migration, contains('conflict_snapshot'));
    expect(migration, contains('for update'));
    expect(migration, contains('pg_advisory_xact_lock'));
    expect(migration, contains('capture_route_state'));
    expect(
      migration,
      contains('apply_task_aware_route_change_proposal_qst286_base'),
    );
  });
}
