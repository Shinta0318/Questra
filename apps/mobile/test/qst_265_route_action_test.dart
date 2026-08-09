import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_route_screen.dart';
import 'package:questra/features/quest/route_replanning_controller.dart';
import 'package:questra/features/quest/route_replanning_model.dart';

void main() {
  setUp(() => _RouteFixtureController.accepted = false);

  testWidgets('route proposal changes nothing until explicit approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixtureController.new),
          missionControllerProvider.overrideWith(_MissionFixtureController.new),
          routeReplanningControllerProvider.overrideWith(
            _RouteFixtureController.new,
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-1')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Arcと航路を見直す'));
    await tester.pumpAndSettle();

    expect(find.text('Arcから航路更新の提案'), findsOneWidget);
    expect(_RouteFixtureController.accepted, isFalse);

    await tester.tap(find.text('選んだ変更を反映'));
    await tester.pumpAndSettle();

    expect(_RouteFixtureController.accepted, isTrue);
    expect(find.text('承認した内容で航路を更新しました。'), findsOneWidget);
  });

  testWidgets('route review error is visible and existing route stays intact', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixtureController.new),
          missionControllerProvider.overrideWith(_MissionFixtureController.new),
          routeReplanningControllerProvider.overrideWith(
            _FailingRouteController.new,
          ),
        ],
        child: const MaterialApp(home: QuestRouteScreen(questId: 'quest-1')),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Arcと航路を見直す'));
    await tester.pumpAndSettle();

    expect(find.textContaining('内容は変更されていません'), findsOneWidget);
    expect(find.text('Missionを準備する'), findsOneWidget);
    expect(find.text('Arcと航路を見直す'), findsOneWidget);
  });
}

class _QuestFixtureController extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-1',
      title: '旅に出る',
      description: '新しい場所を訪ねる',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

class _MissionFixtureController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-1',
      questId: 'quest-1',
      questTitle: '旅に出る',
      title: 'Missionを準備する',
      description: '必要な準備を確認する',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      estimatedDurationDays: 5,
    ),
  ];
}

class _RouteFixtureController extends RouteReplanningController {
  static bool accepted = false;

  @override
  Map<String, RouteChangeProposal> build() => const {};

  @override
  Future<RouteChangeProposal?> review(
    Quest quest,
    List<Mission> missions,
  ) async => _proposal();

  @override
  Future<RouteMutationResult?> accept(
    Quest quest,
    List<Mission> missions,
    RouteChangeProposal proposal,
    Set<String> acceptedItemIds,
  ) async {
    accepted = acceptedItemIds.contains('item-1');
    return RouteMutationResult(
      proposalId: proposal.id,
      questId: proposal.questId,
      routeVersionId: proposal.routeVersionId,
      status: RouteProposalStatus.accepted,
      persistedAtomically: false,
    );
  }
}

class _FailingRouteController extends RouteReplanningController {
  @override
  Map<String, RouteChangeProposal> build() => const {};

  @override
  Future<RouteChangeProposal?> review(Quest quest, List<Mission> missions) =>
      throw StateError('network unavailable');
}

RouteChangeProposal _proposal() => RouteChangeProposal(
  id: 'proposal-1',
  questId: 'quest-1',
  reason: RouteProposalReason.deadlineRisk,
  summary: '期限に合わせて航路を見直します。',
  confidence: 0.88,
  items: [
    RouteChangeItem(
      id: 'item-1',
      action: RouteChangeAction.reschedule,
      title: '達成予測を見直す',
      reason: '現在の予定では希望期限を超えるためです。',
      beforeData: const {'targetDate': '2026-08-01'},
      afterData: const {'targetDate': '2026-09-01'},
    ),
  ],
);
