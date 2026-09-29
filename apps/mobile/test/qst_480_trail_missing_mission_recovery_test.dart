import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('a Quest without Missions offers a direct recovery route', (
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
        GoRoute(path: AppRoutes.trail, builder: (_, _) => const TrailScreen()),
        GoRoute(
          path: '${AppRoutes.quest}/:questId',
          builder: (_, state) =>
              Scaffold(body: Text('Quest ${state.pathParameters['questId']}')),
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
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await _pumpUi(tester);
    await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
    await _pumpUi(tester);
    await tester.tap(find.text('シンガポールへ行く').last);
    await _pumpUi(tester);

    expect(
      find.text('このQuestには利用できるMissionがありません。Quest画面でMissionを作成してください。'),
      findsOneWidget,
    );
    final recovery = find.byKey(const ValueKey('trail-open-quest-for-mission'));
    expect(recovery, findsOneWidget);
    await tester.ensureVisible(recovery);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(recovery);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await _pumpUi(tester);

    expect(find.text('Trailを残す'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/quest/quest-a');
    expect(find.text('Quest quest-a'), findsOneWidget);
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
      description: '家族旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
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
