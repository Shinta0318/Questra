import 'dart:io';

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

  test('Quest detail never bypasses the reviewed Trail composer', () {
    final source = File(
      'lib/features/quest/quest_detail_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('.addQuestTrail(')));
    expect(source, contains('AppRoutes.trailForJourney(questId: quest.id)'));
  });

  testWidgets('Archived empty journey does not offer an invalid create CTA', (
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
            initialFilterQuestId: 'quest-archived',
            initialFilterMissionId: 'mission-archived',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('この航路にはまだTrailがありません。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('trail-filter-empty-create')),
      findsNothing,
    );
    expect(find.text('すべてのTrailを見る'), findsOneWidget);
  });
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-archived',
      title: '過去のQuest',
      description: '履歴だけを確認する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.archived,
      visibility: QuestVisibility.private,
    ),
    Quest(
      id: 'quest-active',
      title: '進行中のQuest',
      description: '現在の航路',
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
      id: 'mission-archived',
      questId: 'quest-archived',
      questTitle: '過去のQuest',
      title: '過去のMission',
      description: '履歴',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
    Mission(
      id: 'mission-active',
      questId: 'quest-active',
      questTitle: '進行中のQuest',
      title: '進行中のMission',
      description: '現在',
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
      id: 'trail-active',
      questId: 'quest-active',
      missionId: 'mission-active',
      title: '現在のTrail',
      summary: '進行中',
      content: '進行中',
      trailType: TrailType.missionRecord,
    ),
  ];
}
