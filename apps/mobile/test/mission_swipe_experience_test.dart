import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/core/experience/haptic_feedback_service.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  testWidgets('Mission can be completed by right swipe or button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(FixtureQuestController.new),
        experienceSettingsRepositoryProvider.overrideWithValue(
          InMemoryExperienceSettingsRepository(),
        ),
        hapticFeedbackServiceProvider.overrideWithValue(
          const NoopHapticFeedbackService(),
        ),
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
    final mission =
        container.read(missionControllerProvider.notifier).addMissionDraft(
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
    expect(find.byType(Dismissible), findsOneWidget);
    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(dismissible.direction, DismissDirection.startToEnd);
    await dismissible.confirmDismiss!(DismissDirection.startToEnd);
    await tester.pump();

    expect(
      container
          .read(missionControllerProvider)
          .singleWhere((item) => item.id == mission.id)
          .status,
      MissionStatus.completed,
    );
    expect(find.text('完了済み'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
  });
}
