import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/route_snapshot_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  final quest = Quest(
    id: 'quest-v2',
    title: 'シンガポールへ行く',
    description: '家族旅行を実現する',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
    targetDate: DateTime(2027, 8),
  );
  final mission = Mission(
    id: 'mission-v2',
    questId: quest.id,
    questTitle: quest.title,
    title: '同行者と旅行日程を決める',
    description: '家族と候補日を比較する',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.normal,
    status: MissionStatus.todo,
    doneCondition: '全員が合意した日程を記録している',
    expectedOutput: '旅行日程',
    estimatedDurationDays: 7,
    difficultyScore: 2,
    sourceRequirement: 'none',
    confidence: 0.82,
  );
  final task = QuestraTask(
    id: 'task-v2',
    questId: quest.id,
    missionId: mission.id,
    title: '候補日を3つ出す',
    action: '同行者の予定を確認して候補日を3つ記録する',
    doneCondition: '候補日が3つ記録されている',
  );

  test('Flutter snapshot v2 survives JSON reload without false stale', () {
    const service = RouteSnapshotService();
    final captured = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task],
    );
    final reloaded = Map<String, Object?>.from(
      jsonDecode(jsonEncode(captured)) as Map,
    );

    expect(captured['snapshotVersion'], RouteSnapshotService.snapshotVersion);
    expect(service.compare(reloaded, captured).isStale, isFalse);
    expect(
      (captured['missions'] as List).single,
      containsPair('doneCondition', mission.doneCondition),
    );
  });

  test('v1 proposal fails closed with an explicit migration message', () {
    const service = RouteSnapshotService();
    final current = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task],
    );
    final legacy = Map<String, Object?>.from(current)..['snapshotVersion'] = 1;

    final conflict = service.compare(legacy, current);

    expect(conflict.changedEntityIds, ['snapshot-version']);
    expect(conflict.message, contains('保存形式'));
    expect(conflict.message, contains('作り直して'));
  });

  test('Mission content changes remain a stale conflict in v2', () {
    const service = RouteSnapshotService();
    final before = service.capture(
      quest: quest,
      missions: [mission],
      tasks: [task],
    );
    final after = service.capture(
      quest: quest,
      missions: [mission.copyWith(title: '旅行日程と同行者を確定する')],
      tasks: [task],
    );

    expect(
      service.compare(before, after).changedEntityIds,
      contains('mission:mission-v2'),
    );
  });

  test('PostgreSQL snapshot uses the same v2 Mission contract', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final migration = File(
      '${root.path}/supabase/migrations/'
      '202609280001_route_snapshot_schema_v2.sql',
    ).readAsStringSync();

    expect(migration, contains("'snapshotVersion', 2"));
    expect(migration, contains("to_char(q.target_date, 'YYYY-MM-DD')"));
    expect(migration, contains('order by dependency_id::text'));
    for (final key in const [
      'title',
      'description',
      'doneCondition',
      'expectedOutput',
      'estimatedDurationDays',
      'difficultyScore',
      'sourceRequirement',
      'confidence',
    ]) {
      expect(migration, contains("'$key'"), reason: key);
    }
    expect(migration, contains('snapshot_schema_version_changed'));
    expect(migration, contains("status = 'stale'"));
  });
}
