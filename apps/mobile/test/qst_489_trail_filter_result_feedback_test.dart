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

  testWidgets('Trail filter announces result count and can be cleared', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
    await _pumpUi(tester);

    expect(find.text('1件のTrailを表示'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('絞り込み結果、Trailを1件表示しています')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trail-entry-trail-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('trail-entry-trail-b')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trail-filter-clear')));
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('trail-filter-result-count')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('trail-entry-trail-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('trail-entry-trail-b')), findsOneWidget);
    semantics.dispose();
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-a', 'シンガポールへ行く'),
    _quest('quest-b', '英語を話せるようになる'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-a', 'quest-a', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-b', 'quest-b', '英語を話せるようになる', '英会話を練習する'),
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
