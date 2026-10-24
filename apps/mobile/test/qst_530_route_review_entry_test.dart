import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_route_screen.dart';
import 'package:questra/features/quest/route_mutation_journal.dart';
import 'package:questra/features/quest/route_replanning_controller.dart';
import 'package:questra/features/quest/route_replanning_model.dart';

void main() {
  testWidgets('Quest detail opens the single route review surface', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.questDetail('quest-a'),
      routes: [
        GoRoute(
          path: '/quest/:questId',
          builder: (_, state) =>
              QuestDetailScreen(questId: state.pathParameters['questId']!),
        ),
        GoRoute(
          path: '/quest/:questId/route',
          builder: (_, state) =>
              QuestRouteScreen(questId: state.pathParameters['questId']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          routeMutationJournalRepositoryProvider.overrideWithValue(
            InMemoryRouteMutationJournalRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final details = find.text('Questの詳細情報');
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    final entry = find.text('航路を見直す');
    for (
      var attempt = 0;
      attempt < 6 && tester.getCenter(entry).dy > 550;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(QuestRouteScreen), findsOneWidget);
    expect(find.text('Questの航路'), findsOneWidget);
  });

  testWidgets('Undo remains reachable after reopening the route screen', (
    tester,
  ) async {
    _UndoRouteFixture.undone = false;
    _UndoRouteFixture.undoCalls = 0;
    _UndoRouteFixture.pendingUndo = null;
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        routeReplanningControllerProvider.overrideWith(_UndoRouteFixture.new),
        routeMutationJournalRepositoryProvider.overrideWithValue(
          InMemoryRouteMutationJournalRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('航路を元に戻す'), findsOneWidget);
    await tester.ensureVisible(find.text('航路を元に戻す'));
    await tester.tap(find.text('航路を元に戻す'));
    await tester.pumpAndSettle();
    expect(_UndoRouteFixture.undoCalls, 1);
    expect(find.text('航路を元に戻しました。'), findsOneWidget);
    expect(find.text('航路を元に戻す'), findsNothing);
  });

  testWidgets('Undo disables repeated taps while the operation is pending', (
    tester,
  ) async {
    _UndoRouteFixture.undone = false;
    _UndoRouteFixture.undoCalls = 0;
    _UndoRouteFixture.pendingUndo = Completer<RouteUndoResult>();
    addTearDown(() => _UndoRouteFixture.pendingUndo = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          routeReplanningControllerProvider.overrideWith(_UndoRouteFixture.new),
          routeMutationJournalRepositoryProvider.overrideWithValue(
            InMemoryRouteMutationJournalRepository(),
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('航路を元に戻す'));
    await tester.tap(find.text('航路を元に戻す'));
    await tester.pump();
    expect(_UndoRouteFixture.undoCalls, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '航路を元に戻しています'),
          )
          .onPressed,
      isNull,
    );
    _UndoRouteFixture.pendingUndo!.complete(
      const RouteUndoResult(RouteUndoStatus.restored, '航路を元に戻しました。'),
    );
    await tester.pumpAndSettle();
    expect(_UndoRouteFixture.undoCalls, 1);
  });

  testWidgets('accepted route with journal warning does not show success', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          routeReplanningControllerProvider.overrideWith(
            _JournalWarningFixture.new,
          ),
          routeMutationJournalRepositoryProvider.overrideWithValue(
            InMemoryRouteMutationJournalRepository(),
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-a')),
      ),
    );
    await tester.pumpAndSettle();
    final review = find.text('Arcと航路を見直す');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();
    await tester.tap(find.text('選んだ変更を反映'));
    await tester.pumpAndSettle();

    expect(find.textContaining('復旧記録を整理できませんでした'), findsOneWidget);
    expect(find.text('承認した内容で航路を更新しました。'), findsNothing);
    expect(find.text('航路を元に戻す'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('route recovery controls fit ${width.toInt()}px at 200%', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questControllerProvider.overrideWith(_QuestFixture.new),
            missionControllerProvider.overrideWith(_MissionFixture.new),
            routeMutationJournalRepositoryProvider.overrideWithValue(
              InMemoryRouteMutationJournalRepository(),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const QuestRouteScreen(questId: 'quest-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Questの航路'), findsOneWidget);
    });
  }
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-a',
      title: '旅に出る',
      description: '新しい場所を訪ねる',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2027, 3, 1),
    ),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-a',
      questId: 'quest-a',
      questTitle: '旅に出る',
      title: '旅程を決める',
      description: '希望の日程を決める',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

class _UndoRouteFixture extends RouteReplanningController {
  static bool undone = false;
  static int undoCalls = 0;
  static Completer<RouteUndoResult>? pendingUndo;

  @override
  Map<String, RouteChangeProposal> build() => const {};

  @override
  String? undoProposalIdForQuest(String questId) => undone ? null : 'proposal';

  @override
  Future<RouteUndoResult> undo(String proposalId) async {
    undoCalls++;
    if (pendingUndo case final pending?) {
      final result = await pending.future;
      undone = result.restored;
      return result;
    }
    undone = true;
    return const RouteUndoResult(RouteUndoStatus.restored, '航路を元に戻しました。');
  }
}

class _JournalWarningFixture extends RouteReplanningController {
  @override
  Map<String, RouteChangeProposal> build() => const {};

  @override
  Future<RouteChangeProposal?> review(
    Quest quest,
    List<Mission> missions,
  ) async {
    return RouteChangeProposal(
      id: 'proposal-warning',
      questId: quest.id,
      reason: RouteProposalReason.manualReview,
      summary: '期限を見直します。',
      confidence: 0.8,
      items: [
        RouteChangeItem(
          action: RouteChangeAction.reschedule,
          title: '期限を見直す',
          reason: '今の状況に合わせる',
          beforeData: const {'targetDate': '2027-03-01'},
          afterData: const {'targetDate': '2027-06-01'},
        ),
      ],
    );
  }

  @override
  Future<RouteMutationResult?> accept(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
    Set<String> acceptedItemIds,
  ) async {
    return RouteMutationResult(
      proposalId: proposal.id,
      questId: quest.id,
      status: RouteProposalStatus.accepted,
      persistedAtomically: false,
      recoveryIncomplete: true,
      staleReason: '航路は更新されましたが、復旧記録を整理できませんでした。',
    );
  }
}
