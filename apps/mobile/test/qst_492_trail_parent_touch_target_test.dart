import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('Trail parent navigation targets are at least 44px high', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/trail',
      routes: [
        GoRoute(path: '/trail', builder: (_, _) => const TrailScreen()),
        GoRoute(
          path: '/quest/:questId',
          builder: (_, _) => const Scaffold(body: Text('Quest detail')),
        ),
        GoRoute(
          path: '/quest/:questId/mission/:missionId',
          builder: (_, _) => const Scaffold(body: Text('Mission detail')),
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

    final quest = find.byKey(
      const ValueKey('trail-parent-quest-quest-singapore'),
    );
    final mission = find.byKey(
      const ValueKey('trail-parent-mission-mission-schedule'),
    );
    expect(tester.getSize(quest).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(mission).height, greaterThanOrEqualTo(44));
  });
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-schedule',
      questId: 'quest-singapore',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '候補日を決める',
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
      id: 'trail-1',
      questId: 'quest-singapore',
      missionId: 'mission-schedule',
      title: '候補月を決めた',
      summary: '家族で日程を相談した。',
      content: '春の旅行を検討する。',
      trailType: TrailType.missionRecord,
    ),
  ];
}
