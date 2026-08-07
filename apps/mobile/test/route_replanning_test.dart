import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/adaptive_route_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/route_replanning_model.dart';
import 'package:questra/features/quest/route_replanning_trigger_service.dart';
import 'package:questra/features/quest/route_replanning_repository.dart';

void main() {
  test('deadline risk becomes a reviewable reschedule diff', () {
    final quest = Quest(
      id: 'quest-1',
      title: '富士山に登る',
      description: '',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2026, 8),
    );
    final mission = Mission(
      id: 'mission-1',
      questId: quest.id,
      questTitle: quest.title,
      title: '登山の準備をする',
      description: '',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.normal,
      status: MissionStatus.todo,
      estimatedDurationDays: 60,
    );

    final proposal = AdaptiveRouteService.buildStructuredProposal(
      quest: quest,
      missions: [mission],
      now: DateTime(2026, 7, 25),
    );

    expect(proposal, isNotNull);
    expect(proposal!.items.single.action, RouteChangeAction.reschedule);
    expect(proposal.status, RouteProposalStatus.pending);
  });

  test('destructive changes require safety level 3', () {
    final proposal = RouteChangeProposal(
      questId: 'quest-1',
      reason: RouteProposalReason.manualReview,
      summary: '変更案',
      confidence: 0.8,
      items: [
        RouteChangeItem(
          action: RouteChangeAction.remove,
          title: 'Missionを外す',
          reason: '不要になったため',
          beforeData: const {'title': '旧Mission'},
          afterData: const {},
          safetyLevel: 2,
        ),
      ],
    );

    expect(
      () => const RouteProposalValidator().validate(proposal),
      throwsFormatException,
    );
  });

  test('manual and urgent triggers bypass the cooldown', () {
    const service = RouteReplanningTriggerService();
    final now = DateTime(2026, 7, 25, 12);
    final last = now.subtract(const Duration(hours: 1));

    expect(
      service
          .decide(
            questId: 'quest-1',
            trigger: RouteReplanningTrigger.weeklyReview,
            lastEvaluatedAt: last,
            now: now,
          )
          .shouldEvaluate,
      isFalse,
    );
    expect(
      service
          .decide(
            questId: 'quest-1',
            trigger: RouteReplanningTrigger.manual,
            lastEvaluatedAt: last,
            now: now,
          )
          .shouldEvaluate,
      isTrue,
    );
    expect(
      service
          .decide(
            questId: 'quest-1',
            trigger: RouteReplanningTrigger.missionDeadlineMissed,
            lastEvaluatedAt: last,
            now: now,
          )
          .shouldEvaluate,
      isTrue,
    );
  });

  test('in-memory repository preserves apply and rollback lifecycle', () async {
    final repository = InMemoryRouteReplanningRepository();
    final item = RouteChangeItem(
      action: RouteChangeAction.reorder,
      targetMissionId: 'mission-1',
      title: '次のMissionへ進む',
      reason: '準備が整ったため',
      beforeData: const {'isToday': false},
      afterData: const {'isToday': true},
      safetyLevel: 1,
    );
    final proposal = RouteChangeProposal(
      questId: 'quest-1',
      reason: RouteProposalReason.manualReview,
      summary: '航路を更新します',
      confidence: 0.9,
      items: [item],
    );
    await repository.saveProposal(proposal);

    final applied = await repository.applyProposal(
      proposal: proposal,
      acceptedItemIds: [item.id],
    );
    expect(applied.status, RouteProposalStatus.accepted);
    expect(applied.persistedAtomically, isFalse);
    expect(
      (await repository.findByQuest(proposal.questId)).single.status,
      RouteProposalStatus.accepted,
    );

    final rolledBack = await repository.rollbackProposal(proposal.id);
    expect(rolledBack.status, RouteProposalStatus.rolledBack);
    expect(
      (await repository.findByQuest(proposal.questId)).single.status,
      RouteProposalStatus.rolledBack,
    );
  });
}
