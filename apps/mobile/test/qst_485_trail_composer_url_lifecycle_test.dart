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
import 'package:questra/l10n/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('saving a route-opened composer removes create from the URL', (
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
        missionId: 'mission-a',
      ),
      routes: [
        GoRoute(
          path: AppRoutes.trail,
          builder: (context, state) {
            final query = state.uri.queryParameters;
            return TrailScreen(
              initialFilterQuestId: query['questId'],
              initialFilterMissionId: query['missionId'],
              openComposer: query['create'] == '1',
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
        child: MaterialApp.router(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await _pumpUi(tester);
    expect(find.text('Trailを残す'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('trail-quick-note')),
      '旅行日程の候補を家族と確認した',
    );
    final save = find.widgetWithText(FilledButton, 'Trailを保存');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await _pumpUi(tester);

    expect(find.byKey(const Key('questra-modal-surface')), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/trail?questId=quest-a&missionId=mission-a',
    );
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}
