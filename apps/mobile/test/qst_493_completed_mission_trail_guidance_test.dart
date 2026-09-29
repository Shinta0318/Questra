import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
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

  testWidgets('completed Mission remains available for reflective Trail', (
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
    final router = GoRouter(
      initialLocation: AppRoutes.trailComposerForQuest(
        'quest-a',
        missionId: 'mission-completed',
      ),
      routes: [
        GoRoute(
          path: AppRoutes.trail,
          builder: (_, state) => TrailScreen(
            initialFilterQuestId: state.uri.queryParameters['questId'],
            initialFilterMissionId: state.uri.queryParameters['missionId'],
            openComposer: state.uri.queryParameters['create'] == '1',
          ),
        ),
        GoRoute(
          path: '${AppRoutes.quest}/:questId',
          builder: (_, _) => const Scaffold(body: Text('Quest detail')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('完了したMissionにも、振り返りや学びとしてTrailを残せます。'), findsOneWidget);
    final selector = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-mission-selector-quest-a')),
    );
    expect(selector.initialValue, 'mission-completed');
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
    Mission(
      id: 'mission-completed',
      questId: 'quest-a',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '出発日と帰国日を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    ),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}
