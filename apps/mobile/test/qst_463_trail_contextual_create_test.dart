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

  testWidgets('Mission scoped Trail creation inherits the visible journey', (
    tester,
  ) async {
    final container = _container();
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

    await tester.tap(find.text('Trailを残す').first);
    await _pumpUi(tester);

    final questField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-quest-selector')),
    );
    final missionField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-mission-selector-quest-a')),
    );
    expect(questField.initialValue, 'quest-a');
    expect(missionField.initialValue, 'mission-a');
  });

  testWidgets('Quest scoped creation keeps Mission selection open', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TrailScreen(initialFilterQuestId: 'quest-a'),
        ),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('Trailを残す').first);
    await _pumpUi(tester);

    final missionField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-mission-selector-quest-a')),
    );
    expect(missionField.initialValue, isNull);
    expect(missionField.onChanged, isNotNull);
  });
}

ProviderContainer _container() => ProviderContainer(
  overrides: [
    questControllerProvider.overrideWith(_QuestFixture.new),
    missionControllerProvider.overrideWith(_MissionFixture.new),
    trailControllerProvider.overrideWith(_TrailFixture.new),
  ],
);

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-a',
      title: 'シンガポールへ行く',
      description: '旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-a',
      questId: 'quest-a',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '候補月を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    Trail(
      id: 'trail-a',
      questId: 'quest-a',
      missionId: 'mission-a',
      title: '候補月を決めた',
      summary: '春を候補にした',
      content: '家族で相談した',
      trailType: TrailType.missionRecord,
    ),
  ];
}
