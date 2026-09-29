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

  testWidgets('Trail Mission selector prioritizes unfinished route order', (
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
          home: TrailScreen(initialFilterQuestId: 'quest-a'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const ValueKey('trail-mission-selector-quest-a')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final first = find.text('宿泊候補を比較する').last;
    final second = find.text('航空券を比較する').last;
    final completed = find.text('旅行時期を決める（完了）').last;
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(completed, findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(
      tester.getTopLeft(second).dy,
      lessThan(tester.getTopLeft(completed).dy),
    );
  });
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
    _mission('mission-completed', '旅行時期を決める', MissionStatus.completed, 0),
    _mission('mission-second', '航空券を比較する', MissionStatus.todo, 10),
    _mission('mission-first', '宿泊候補を比較する', MissionStatus.todo, 2),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}

Mission _mission(
  String id,
  String title,
  MissionStatus status,
  int orderIndex,
) => Mission(
  id: id,
  questId: 'quest-a',
  questTitle: 'シンガポールへ行く',
  title: title,
  description: title,
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: status,
  orderIndex: orderIndex,
);
