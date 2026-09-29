import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('Trail Quest selector prioritizes active journeys', (
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
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final active = find.text('シンガポールへ行く').last;
    final draft = find.text('写真集を作る').last;
    final completed = find.text('富士山に登る（完了）').last;
    expect(active, findsOneWidget);
    expect(draft, findsOneWidget);
    expect(completed, findsOneWidget);
    expect(tester.getTopLeft(active).dy, lessThan(tester.getTopLeft(draft).dy));
    expect(
      tester.getTopLeft(draft).dy,
      lessThan(tester.getTopLeft(completed).dy),
    );
  });
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-completed', '富士山に登る', QuestStatus.completed),
    _quest('quest-draft', '写真集を作る', QuestStatus.draft),
    _quest('quest-active', 'シンガポールへ行く', QuestStatus.active),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => const [];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}

Quest _quest(String id, String title, QuestStatus status) => Quest(
  id: id,
  title: title,
  description: title,
  difficulty: QuestDifficulty.normal,
  status: status,
  visibility: QuestVisibility.private,
);
