import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_draft_repository.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('a draft from another Quest requires an explicit decision', (
    tester,
  ) async {
    final repository = InMemoryTrailDraftRepository();
    final storedDraft = TrailComposerDraft(
      id: 'draft-a',
      questId: 'quest-a',
      missionId: 'mission-a',
      title: '',
      summary: '航空券の候補日を家族と相談した',
      content: '',
      showDetails: false,
      updatedAt: DateTime.now(),
    );
    await repository.save('owner-a', storedDraft);
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        trailControllerProvider.overrideWith(_TrailFixture.new),
        trailDraftRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.trailComposerForQuest('quest-b'),
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

    expect(
      find.byKey(const ValueKey('trail-draft-context-conflict')),
      findsOneWidget,
    );
    final questBefore = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-quest-selector')),
    );
    expect(questBefore.initialValue, 'quest-b');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('trail-quick-note')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(await repository.load('owner-a'), same(storedDraft));

    await tester.tap(
      find.byKey(const ValueKey('trail-open-conflicting-draft')),
    );
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('trail-draft-context-conflict')),
      findsNothing,
    );
    final questAfter = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('trail-quest-selector')),
    );
    expect(questAfter.initialValue, 'quest-a');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('trail-quick-note')))
          .controller
          ?.text,
      storedDraft.summary,
    );
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'Navigator',
    ),
  );
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('quest-a', 'シンガポールへ行く'),
    _quest('quest-b', '英語を話せるようになる'),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('mission-a', 'quest-a', 'シンガポールへ行く', '旅行日程を決める'),
    _mission('mission-b', 'quest-b', '英語を話せるようになる', '英会話を練習する'),
  ];
}

class _TrailFixture extends TrailController {
  @override
  List<Trail> build() => const [];
}

Quest _quest(String id, String title) => Quest(
  id: id,
  title: title,
  description: title,
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission(String id, String questId, String questTitle, String title) =>
    Mission(
      id: id,
      questId: questId,
      questTitle: questTitle,
      title: title,
      description: title,
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );
