import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest_journey/quest_journey_contract.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

const _questId = 'quest-singapore';

final _quest = Quest(
  id: _questId,
  title: '家族でシンガポール旅行を実現する',
  description: '食事と観光を楽しむ',
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  test('return location is bound to the Trail composer and same Quest', () {
    final returnTo = AppRoutes.trailComposerForQuest(_questId);
    expect(returnTo, '/trail?questId=$_questId&create=1');
    expect(
      AppRoutes.questDetailForTrailMission(_questId),
      '/quest/$_questId?returnTo=%2Ftrail%3FquestId%3Dquest-singapore%26create%3D1',
    );
    expect(
      AppRoutes.safeTrailComposerReturnLocation(returnTo, questId: _questId),
      returnTo,
    );
    expect(
      AppRoutes.safeTrailComposerReturnLocation(
        '/trail?questId=other&create=1',
        questId: _questId,
      ),
      isNull,
    );
    expect(
      AppRoutes.safeTrailComposerReturnLocation(
        'https://example.com/trail?questId=$_questId&create=1',
        questId: _questId,
      ),
      isNull,
    );
  });

  testWidgets('creating a Mission returns to the scoped Trail composer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.questDetailForTrailMission(_questId),
      routes: [
        GoRoute(
          path: '${AppRoutes.quest}/:questId',
          builder: (_, state) => QuestDetailScreen(
            questId: state.pathParameters['questId']!,
            initialJourneyMode: QuestJourneyMode.plan,
            returnLocation: state.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: AppRoutes.trail,
          builder: (_, state) => Scaffold(
            body: Text(
              'Trail ${state.uri.queryParameters['questId']} '
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
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _pumpUi(tester);
    final create = find.text('Missionを追加');
    await tester.scrollUntilVisible(
      create,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpUi(tester);
    await tester.tap(create);
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '旅行日程を決める');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '出発日と帰国日をカレンダーへ保存する',
    );
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await _pumpUi(tester);

    expect(container.read(missionControllerProvider), hasLength(1));
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.trail);
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      containsPair('questId', _questId),
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters,
      containsPair(
        'missionId',
        container.read(missionControllerProvider).single.id,
      ),
    );
    expect(find.text('Trail $_questId 1'), findsOneWidget);
  });

  testWidgets('Quest-scoped Trail entry opens with the Quest preselected', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionWithOneFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.trailComposerForQuest(_questId),
      routes: [
        GoRoute(
          path: AppRoutes.trail,
          builder: (_, state) => TrailScreen(
            initialFilterQuestId: state.uri.queryParameters['questId'],
            openComposer: state.uri.queryParameters['create'] == '1',
          ),
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUi(tester);

    expect(find.text('Trailを残す'), findsOneWidget);
    expect(find.text(_quest.title), findsWidgets);
    expect(
      find.byKey(const ValueKey('trail-mission-selector-$_questId')),
      findsOneWidget,
    );
    expect(find.text('Missionを選択'), findsOneWidget);
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 16));
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [_quest];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => const [];
}

class _MissionWithOneFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-trip-date',
      questId: _questId,
      questTitle: _quest.title,
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
