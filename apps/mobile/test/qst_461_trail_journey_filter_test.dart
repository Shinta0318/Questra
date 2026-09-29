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

  testWidgets('Questを選ぶと対応するTrailとMissionだけに絞り込める', (tester) async {
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

    expect(
      find.byKey(const ValueKey('trail-entry-trail-singapore')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail-entry-trail-english')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('trail-filter-quest')));
    await _pumpUi(tester);
    await tester.tap(find.text('シンガポールへ行く').last);
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('trail-entry-trail-singapore')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail-entry-trail-english')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('trail-filter-mission-quest-singapore')),
    );
    await _pumpUi(tester);
    expect(find.text('英語で注文する'), findsNothing);
    await tester.tap(find.text('旅行日程を決める').last);
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('trail-entry-trail-singapore')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail-entry-trail-english')),
      findsNothing,
    );
  });

  testWidgets('絞り込み解除ですべてのTrailへ戻れる', (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('trail-filter-quest')));
    await _pumpUi(tester);
    await tester.tap(find.text('シンガポールへ行く').last);
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('trail-filter-clear')));
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('trail-entry-trail-singapore')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trail-entry-trail-english')),
      findsOneWidget,
    );
  });

  testWidgets('360px幅ではフィルターを1カラムで表示してoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
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

    expect(find.byKey(const ValueKey('trail-filter-quest')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trail-filter-mission-all')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-singapore', 'シンガポールへ行く'),
    _quest('quest-english', '英語で会話できるようになる'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-schedule', 'quest-singapore', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-order', 'quest-english', '英語で会話できるようになる', '英語で注文する'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => [
    _trail('trail-singapore', 'quest-singapore', 'mission-schedule', '旅程を決めた'),
    _trail('trail-english', 'quest-english', 'mission-order', '英会話を練習した'),
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
