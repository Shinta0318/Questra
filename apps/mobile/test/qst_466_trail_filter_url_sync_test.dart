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

  testWidgets('Trail filters update and clear the browser-safe URL', (
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
      initialLocation: AppRoutes.trail,
      routes: [
        GoRoute(
          path: AppRoutes.trail,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            return TrailScreen(
              initialFilterQuestId: query['questId'],
              initialFilterMissionId: query['missionId'],
              onFilterRouteChanged: (questId, missionId) => context.go(
                questId == null
                    ? AppRoutes.trail
                    : AppRoutes.trailForJourney(
                        questId: questId,
                        missionId: missionId,
                      ),
              ),
            );
          },
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
    await _pumpUi(tester);

    await tester.tap(find.byKey(const ValueKey('trail-filter-quest')));
    await _pumpUi(tester);
    await tester.tap(find.text('シンガポールへ行く').last);
    await _pumpUi(tester);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/trail?questId=quest-a',
    );

    await tester.tap(
      find.byKey(const ValueKey('trail-filter-mission-quest-a')),
    );
    await _pumpUi(tester);
    await tester.tap(find.text('旅行日程を決める').last);
    await _pumpUi(tester);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/trail?questId=quest-a&missionId=mission-a',
    );

    await tester.tap(find.byKey(const ValueKey('trail-filter-clear')));
    await _pumpUi(tester);
    expect(router.routeInformationProvider.value.uri.toString(), '/trail');
  });
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
