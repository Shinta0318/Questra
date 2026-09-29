import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
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

  test('Trail scoped route carries Quest and optional Mission IDs', () {
    expect(
      AppRoutes.trailForJourney(questId: 'quest-a'),
      '/trail?questId=quest-a',
    );
    expect(
      AppRoutes.trailForJourney(questId: 'quest-a', missionId: 'mission-a'),
      '/trail?questId=quest-a&missionId=mission-a',
    );
  });

  testWidgets('Mission scoped entry shows only the selected journey Trail', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TrailScreen(
            initialFilterQuestId: 'quest-a',
            initialFilterMissionId: 'mission-a',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('trail-entry-trail-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('trail-entry-trail-b')), findsNothing);
    expect(
      find.byKey(const ValueKey('trail-filter-mission-quest-a')),
      findsOneWidget,
    );
  });
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-a', 'シンガポールへ行く'),
    _quest('quest-b', '英語を学ぶ'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-a', 'quest-a', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-b', 'quest-b', '英語を学ぶ', '英会話を練習する'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    _trail('trail-a', 'quest-a', 'mission-a', '候補月を決めた'),
    _trail('trail-b', 'quest-b', 'mission-b', '英会話を練習した'),
  ];
}

Quest _quest(String id, String title) => Quest(
  id: id,
  title: title,
  description: title,
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission(String id, String questId, String questTitle, String title) =>
    Mission(
      id: id,
      questId: questId,
      questTitle: questTitle,
      title: title,
      description: title,
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );

Trail _trail(String id, String questId, String missionId, String title) =>
    Trail(
      id: id,
      questId: questId,
      missionId: missionId,
      title: title,
      summary: title,
      content: title,
      trailType: TrailType.missionRecord,
    );
