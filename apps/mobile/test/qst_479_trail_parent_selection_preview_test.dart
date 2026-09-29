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

  for (final width in [360.0, 430.0]) {
    testWidgets('selected Trail parent stays explicit at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
          child: const MaterialApp(home: TrailScreen()),
        ),
      );
      await _pumpUi(tester);
      await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
      await _pumpUi(tester);
      await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
      await _pumpUi(tester);
      await tester.tap(find.text('シンガポールへ行く').last);
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const ValueKey('trail-mission-selector-quest-a')),
      );
      await _pumpUi(tester);
      await tester.tap(find.text('旅行日程を決める').last);
      await _pumpUi(tester);

      final preview = find.byKey(
        const ValueKey('trail-parent-selection-preview'),
      );
      expect(preview, findsOneWidget);
      expect(find.text('この航路に記録します'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trail-parent-quest-quest-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('trail-parent-mission-mission-a')),
        findsOneWidget,
      );
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: preview, matching: find.byType(Semantics)).first,
      );
      expect(
        semantics.properties.label,
        '保存先はQuest「シンガポールへ行く」、Mission「旅行日程を決める」です',
      );
      expect(tester.takeException(), isNull);
    });
  }
}

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
      description: '家族旅行を実現する',
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
  List<Trail> build() => const [];
}
