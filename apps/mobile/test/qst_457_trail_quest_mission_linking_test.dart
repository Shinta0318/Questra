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
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('Trail画面ではQuest選択後に同じQuestのMissionだけを選んで保存する', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await _pumpUi(tester);

    expect(find.text('1. Questを選ぶ'), findsOneWidget);
    expect(find.text('2. Missionを選ぶ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
    await _pumpUi(tester);
    expect(find.text('保管済みQuest'), findsNothing);
    await tester.tap(find.text('シンガポールへ行く').last);
    await _pumpUi(tester);

    await tester.tap(
      find.byKey(const ValueKey('trail-mission-selector-quest-singapore')),
    );
    await _pumpUi(tester);
    expect(find.text('英語試験を申し込む'), findsNothing);
    expect(find.text('置き換え前のMission'), findsNothing);
    await tester.tap(find.text('旅行日程を決める').last);
    await _pumpUi(tester);

    await tester.enterText(
      find.byKey(const ValueKey('trail-quick-note')),
      '家族で行ける日程を相談し、候補月を決めた。',
    );
    await tester.ensureVisible(find.text('Trailを保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Trailを保存'));
    await _pumpUi(tester);

    final trail = container.read(trailControllerProvider).single;
    expect(trail.questId, 'quest-singapore');
    expect(trail.missionId, 'mission-schedule');
    expect(trail.trailType.name, 'missionRecord');
  });

  testWidgets('Missionを選ばない限りTrailは保存しない', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
    await _pumpUi(tester);
    await tester.tap(find.text('英語で会話できるようになる').last);
    await _pumpUi(tester);
    await tester.enterText(
      find.byKey(const ValueKey('trail-quick-note')),
      '今日は発音練習をした。',
    );
    await tester.ensureVisible(find.text('Trailを保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Trailを保存'));
    await _pumpUi(tester);

    expect(find.text('Questに紐づくMissionを選択してください。'), findsOneWidget);
    expect(container.read(trailControllerProvider), isEmpty);
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
    Quest(
      id: 'quest-archived',
      title: '保管済みQuest',
      description: '選択対象外',
      difficulty: QuestDifficulty.easy,
      status: QuestStatus.archived,
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
      title: '英語試験を申し込む',
    ),
    _mission(
      id: 'mission-removed',
      questId: 'quest-singapore',
      questTitle: 'シンガポールへ行く',
      title: '置き換え前のMission',
      routeState: MissionRouteState.removed,
    ),
  ];
}

Mission _mission({
  required String id,
  required String questId,
  required String questTitle,
  required String title,
  MissionRouteState routeState = MissionRouteState.active,
}) {
  return Mission(
    id: id,
    questId: questId,
    questTitle: questTitle,
    title: title,
    description: title,
    guideType: GuideType.route,
    difficulty: MissionDifficulty.easy,
    status: MissionStatus.todo,
    routeState: routeState,
  );
}
