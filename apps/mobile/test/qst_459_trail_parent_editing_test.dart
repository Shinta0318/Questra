import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('手動Trailは編集画面でQuestとMissionを一緒に変更できる', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_ManualTrailFixture.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Trailメニュー'));
    await _pumpUi(tester);
    await tester.tap(find.text('編集').last);
    await _pumpUi(tester);

    expect(find.text('紐づけ先'), findsOneWidget);
    expect(find.textContaining('シンガポールへ行く'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('trail-edit-change-parent')));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('trail-edit-quest-selector')));
    await _pumpUi(tester);
    await tester.tap(find.text('英語で会話できるようになる').last);
    await _pumpUi(tester);

    await tester.tap(
      find.byKey(const ValueKey('trail-edit-mission-selector-quest-english')),
    );
    await _pumpUi(tester);
    await tester.tap(find.text('旅行英会話を練習する').last);
    await _pumpUi(tester);

    await tester.ensureVisible(find.text('変更を保存'));
    await tester.tap(find.text('変更を保存'));
    await _pumpUi(tester);

    final updated = container.read(trailControllerProvider).single;
    expect(updated.questId, 'quest-english');
    expect(updated.missionId, 'mission-english');
    expect(updated.taskId, isNull);
    expect(updated.trailType, TrailType.missionRecord);
  });

  testWidgets('Task起点Trailでは親航路を変更できない', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TaskTrailFixture.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.byTooltip('Trailメニュー'));
    await _pumpUi(tester);
    await tester.tap(find.text('編集').last);
    await _pumpUi(tester);

    expect(find.textContaining('履歴保護のため変更できません'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trail-edit-change-parent')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('trail-edit-quest-selector')),
      findsNothing,
    );
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-singapore',
      title: 'シンガポールへ行く',
      description: '家族旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
    Quest(
      id: 'quest-english',
      title: '英語で会話できるようになる',
      description: '旅行先で会話する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission(
      id: 'mission-schedule',
      questId: 'quest-singapore',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
    ),
    _mission(
      id: 'mission-english',
      questId: 'quest-english',
      questTitle: '英語で会話できるようになる',
      title: '旅行英会話を練習する',
    ),
  ];
}

class _ManualTrailFixture extends TrailController {
  @override
  List<Trail> build() => [_trail()];

  @override
  Future<bool> updateTrailAndWait(Trail updatedTrail) async {
    state = [updatedTrail];
    return true;
  }
}

class _TaskTrailFixture extends _ManualTrailFixture {
  @override
  List<Trail> build() => [_trail(taskId: 'task-book-flight')];
}

Trail _trail({String? taskId}) => Trail(
  id: 'trail-1',
  questId: 'quest-singapore',
  missionId: 'mission-schedule',
  taskId: taskId,
  title: '候補月を決めた',
  summary: '家族で日程を相談した。',
  content: '春の旅行を検討する。',
  trailType: TrailType.missionRecord,
  sourceType: taskId == null ? 'manual' : 'task_trail',
);

Mission _mission({
  required String id,
  required String questId,
  required String questTitle,
  required String title,
}) => Mission(
  id: id,
  questId: questId,
  questTitle: questTitle,
  title: title,
  description: title,
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.todo,
);
