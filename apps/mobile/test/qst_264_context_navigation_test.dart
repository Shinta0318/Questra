import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test(
    'Mission Arc route preserves focus, visible prompt, and return path',
    () {
      final location = AppRoutes.arcForMission(
        questId: 'quest-1',
        missionId: 'mission-1',
        prompt: '旅程を相談したい。',
        returnTo: AppRoutes.missionDetail('quest-1', 'mission-1'),
      );
      final uri = Uri.parse(location);

      expect(uri.path, AppRoutes.arc);
      expect(uri.queryParameters['questId'], 'quest-1');
      expect(uri.queryParameters['missionId'], 'mission-1');
      expect(uri.queryParameters['prompt'], '旅程を相談したい。');
      expect(
        uri.queryParameters['returnTo'],
        AppRoutes.missionDetail('quest-1', 'mission-1'),
      );
    },
  );

  testWidgets('Arc shows Mission context and keeps the consultation draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionControllerProvider.overrideWith(_MissionContextController.new),
        ],
        child: const MaterialApp(
          home: ArcScreen(
            initialPrompt: '「旅程を確定する」を進める次の一歩を相談したい。',
            focusQuestId: 'quest-1',
            focusMissionId: 'mission-1',
            returnLocation: '/quest/quest-1/mission/mission-1',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('旅に出る'), findsOneWidget);
    expect(find.text('旅程を確定する'), findsOneWidget);
    expect(find.byTooltip('Missionへ戻る'), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(const ValueKey('arc-chat-input')),
    );
    expect(input.controller?.text, '「旅程を確定する」を進める次の一歩を相談したい。');
  });

  testWidgets('Arc ignores an external return location', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ArcScreen(returnLocation: 'https://example.com/leave'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Missionへ戻る'), findsNothing);
  });
}

class _MissionContextController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-1',
      questId: 'quest-1',
      questTitle: '旅に出る',
      title: '旅程を確定する',
      description: '予約できる旅程を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}
