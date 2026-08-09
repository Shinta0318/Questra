import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/features/mission/widgets/mission_card.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  testWidgets('Mission cannot bypass Task progress by swipe or direct button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(FixtureQuestController.new),
      ],
    );
    addTearDown(container.dispose);
    final quest = container.read(questControllerProvider).first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MissionScreen()),
      ),
    );
    await tester.pump();
    final mission = container
        .read(missionControllerProvider.notifier)
        .addMissionDraft(
          quest: quest,
          title: '小さな一歩',
          description: 'スワイプ体験を確認する',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          isToday: true,
        );
    await tester.pump();

    expect(container.read(missionControllerProvider), hasLength(1));
    expect(find.text('小さな一歩'), findsOneWidget);
    expect(find.byType(MissionCard), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('Missionを完了'), findsNothing);
    expect(find.text('Taskを見る'), findsOneWidget);

    expect(
      container
          .read(missionControllerProvider)
          .singleWhere((item) => item.id == mission.id)
          .status,
      MissionStatus.todo,
    );
  });
}
