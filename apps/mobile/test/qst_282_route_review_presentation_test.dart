import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_presentation.dart';

void main() {
  test('Task変更を対象階層と日本語差分で説明する', () {
    final item = RouteChangeItem(
      action: RouteChangeAction.reschedule,
      targetMissionId: 'mission-1',
      targetTaskId: 'task-1',
      title: '次のTaskの予定を合わせる',
      reason: '航路へ合わせるため',
      beforeData: const {'scheduledDate': null, 'orderIndex': 3},
      afterData: const {'scheduledDate': '2026-08-09', 'orderIndex': 1},
    );

    expect(routeChangeTargetLabel(item), 'Task');
    expect(routeChangeActionLabel(item.action), '日程変更');
    expect(routeChangeDiffLabel(item), contains('予定日: なし'));
    expect(routeChangeDiffLabel(item), contains('順序: 1'));
  });

  test('MissionとQuestの変更も対象を区別する', () {
    final mission = RouteChangeItem(
      action: RouteChangeAction.split,
      targetMissionId: 'mission-1',
      title: 'Missionを分ける',
      reason: '成果を確認しやすくするため',
      beforeData: const {},
      afterData: const {
        'missions': [1, 2],
      },
    );
    final quest = RouteChangeItem(
      action: RouteChangeAction.reschedule,
      title: '期限を見直す',
      reason: '現在の進捗に合わせるため',
      beforeData: const {'targetDate': '2026-08'},
      afterData: const {'targetDate': '2026-09'},
    );

    expect(routeChangeTargetLabel(mission), 'Mission');
    expect(routeChangeDiffLabel(mission), contains('Mission: 2件'));
    expect(routeChangeTargetLabel(quest), 'Quest');
    expect(routeChangeDiffLabel(quest), contains('Quest期限: 2026-09'));
  });
}
