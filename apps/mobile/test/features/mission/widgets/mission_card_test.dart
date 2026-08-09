import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/widgets/mission_card.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  testWidgets('Mission、進捗、次のTask、主操作を一枚で示す', (tester) async {
    final mission = Mission(
      id: 'mission-1',
      questId: 'quest-1',
      questTitle: '旅に出る',
      title: '旅程を確定する',
      description: '予約可能な旅程が決まっている',
      successCondition: '日程と移動手段が確定している',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      confidence: 0.99,
    );
    final task = QuestraTask(
      id: 'task-1',
      questId: 'quest-1',
      missionId: 'mission-1',
      title: '候補日を3つ選ぶ',
      action: 'カレンダーを確認する',
      doneCondition: '候補日が3つある',
      status: TaskStatus.ready,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissionCard(
            mission: mission,
            tasks: [task],
            completedMissionIds: const {},
            onPrimaryPressed: (_) {},
            onMenuSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('MISSION'), findsOneWidget);
    expect(find.text('0 / 1 Task'), findsOneWidget);
    expect(find.text('次のTask'), findsOneWidget);
    expect(find.text('候補日を3つ選ぶ'), findsOneWidget);
    expect(find.text('次のTaskを始める'), findsOneWidget);
    expect(find.textContaining('確度'), findsNothing);

    await tester.tap(find.byTooltip('Missionのその他の操作'));
    await tester.pumpAndSettle();
    expect(find.text('Arcに相談'), findsOneWidget);
    expect(find.text('実行サポート'), findsOneWidget);
    expect(find.text('Missionを削除'), findsOneWidget);
  });
}
