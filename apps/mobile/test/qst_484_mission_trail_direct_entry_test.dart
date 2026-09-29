import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_detail_screen.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  testWidgets('Mission detail opens a Mission-scoped Trail composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [missionControllerProvider.overrideWith(_MissionFixture.new)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/mission-detail',
      routes: [
        GoRoute(
          path: '/mission-detail',
          builder: (_, _) => const MissionDetailScreen(missionId: 'mission-a'),
        ),
        GoRoute(
          path: AppRoutes.trail,
          builder: (_, state) => Scaffold(
            body: Text(
              'Trail ${state.uri.queryParameters['questId']} '
              '${state.uri.queryParameters['missionId']} '
              '${state.uri.queryParameters['create']}',
            ),
          ),
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
    await tester.pump(const Duration(milliseconds: 400));
    final action = find.widgetWithText(OutlinedButton, 'Trailを残す');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/trail?questId=quest-a&missionId=mission-a&create=1',
    );
    expect(find.text('Trail quest-a mission-a 1'), findsOneWidget);
  });
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-a',
      questId: 'quest-a',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '出発日と帰国日を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}
