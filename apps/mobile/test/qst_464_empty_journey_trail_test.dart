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

  testWidgets(
    'A scoped Mission with zero Trails remains valid and actionable',
    (tester) async {
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
              initialFilterQuestId: 'quest-empty',
              initialFilterMissionId: 'mission-empty',
            ),
          ),
        ),
      );
      await _pumpUi(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('この航路にはまだTrailがありません。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trail-filter-mission-quest-empty')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('trail-filter-empty-create')));
      await _pumpUi(tester);

      final questField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('trail-quest-selector')),
      );
      final missionField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('trail-mission-selector-quest-empty')),
      );
      expect(questField.initialValue, 'quest-empty');
      expect(missionField.initialValue, 'mission-empty');
    },
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-empty', 'シンガポールへ行く'),
    _quest('quest-other', '英語を学ぶ'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-empty', 'quest-empty', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-other', 'quest-other', '英語を学ぶ', '英会話を練習する'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    Trail(
      id: 'trail-other',
      questId: 'quest-other',
      missionId: 'mission-other',
      title: '英会話を練習した',
      summary: '練習記録',
      content: '10分話した',
      trailType: TrailType.missionRecord,
    ),
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
