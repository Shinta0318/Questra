import '../mission/mission_model.dart';
import 'quest_model.dart';
import 'route_replanning_model.dart';

enum RouteReplanReason { ahead, deadlineRisk, stalled, contextChanged }

class RouteReplanProposal {
  const RouteReplanProposal({
    required this.reason,
    required this.title,
    required this.message,
    required this.preservedMissionIds,
    this.recommendedTargetDate,
  });

  final RouteReplanReason reason;
  final String title;
  final String message;
  final List<String> preservedMissionIds;
  final DateTime? recommendedTargetDate;
}

abstract final class AdaptiveRouteService {
  static RouteReplanProposal? evaluate({
    required Quest quest,
    required List<Mission> missions,
    DateTime? now,
  }) {
    if (missions.isEmpty) return null;
    final today = now ?? DateTime.now();
    final completed = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .toList(growable: false);
    final pending = missions
        .where((mission) => mission.status != MissionStatus.completed)
        .toList(growable: false);
    final preserved = completed
        .map((mission) => mission.id)
        .toList(growable: false);
    final remainingDays = pending.fold<int>(
      0,
      (sum, mission) => sum + (mission.estimatedDurationDays ?? 3),
    );
    final projected = today.add(Duration(days: remainingDays));

    if (quest.targetDate != null && projected.isAfter(quest.targetDate!)) {
      return RouteReplanProposal(
        reason: RouteReplanReason.deadlineRisk,
        title: '期限に合わせて航路を調整',
        message: '現在の航路では期限を超える見込みです。完了済みのMissionは残し、次の一歩を組み直します。',
        preservedMissionIds: preserved,
        recommendedTargetDate: projected,
      );
    }

    final oldestPending = pending.isEmpty
        ? null
        : pending
              .map((mission) => mission.createdAt)
              .reduce((left, right) => left.isBefore(right) ? left : right);
    if (oldestPending != null && today.difference(oldestPending).inDays >= 14) {
      return RouteReplanProposal(
        reason: RouteReplanReason.stalled,
        title: '航路を小さく描き直す',
        message: 'Missionが少し停滞しています。条件を見直し、今日始められる大きさに分けましょう。',
        preservedMissionIds: preserved,
      );
    }

    if (completed.length >= 2 && completed.length / missions.length >= 0.6) {
      return RouteReplanProposal(
        reason: RouteReplanReason.ahead,
        title: '次の星を前倒しで探す',
        message: '予定より良いペースです。完了済みの記録を残したまま、次のMissionを再評価できます。',
        preservedMissionIds: preserved,
      );
    }
    return null;
  }

  static RouteChangeProposal? buildStructuredProposal({
    required Quest quest,
    required List<Mission> missions,
    DateTime? now,
  }) {
    final evaluated = evaluate(quest: quest, missions: missions, now: now);
    final pending =
        missions
            .where((mission) => mission.status != MissionStatus.completed)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (evaluated == null || pending.isEmpty) {
      return null;
    }

    final items = switch (evaluated.reason) {
      RouteReplanReason.deadlineRisk => [
        RouteChangeItem(
          action: RouteChangeAction.reschedule,
          title: 'Questの達成予測を見直す',
          reason: '残りMissionの推定日数が希望期限を超えています。',
          beforeData: {'targetDate': quest.targetDate?.toIso8601String()},
          afterData: {
            'targetDate': evaluated.recommendedTargetDate?.toIso8601String(),
          },
        ),
      ],
      RouteReplanReason.stalled => [
        RouteChangeItem(
          action: RouteChangeAction.split,
          targetMissionId: pending.first.id,
          title: '「${pending.first.title}」を小さく分ける',
          reason: '未着手期間が長いため、始めやすい2つのMissionに分割します。',
          beforeData: {
            'title': pending.first.title,
            'estimatedDays': pending.first.estimatedDurationDays,
          },
          afterData: {
            'missions': [
              {'title': '${pending.first.title}の準備をする', 'estimatedDays': 2},
              {
                'title': '${pending.first.title}を実行する',
                'estimatedDays': pending.first.estimatedDurationDays ?? 3,
              },
            ],
          },
        ),
      ],
      RouteReplanReason.ahead => [
        RouteChangeItem(
          action: RouteChangeAction.reorder,
          targetMissionId: pending.first.id,
          title: '次のMissionを今日の一歩にする',
          reason: '予定より良いペースなので、次のMissionを前倒しできます。',
          beforeData: {'isToday': pending.first.isToday},
          afterData: {'isToday': true},
          safetyLevel: 1,
        ),
      ],
      RouteReplanReason.contextChanged => [
        RouteChangeItem(
          action: RouteChangeAction.reestimate,
          title: '明示された状況をもとに再評価する',
          reason: '利用を許可された状況変化だけを航路評価へ反映します。',
          beforeData: const {},
          afterData: const {'requiresAiReevaluation': true},
        ),
      ],
    };
    return const RouteProposalValidator().validate(
      RouteChangeProposal(
        questId: quest.id,
        reason: switch (evaluated.reason) {
          RouteReplanReason.deadlineRisk => RouteProposalReason.deadlineRisk,
          RouteReplanReason.stalled => RouteProposalReason.stalled,
          RouteReplanReason.ahead => RouteProposalReason.aheadOfSchedule,
          RouteReplanReason.contextChanged =>
            RouteProposalReason.contextChanged,
        },
        summary: evaluated.message,
        confidence: evaluated.reason == RouteReplanReason.deadlineRisk
            ? 0.88
            : 0.76,
        items: items,
        routeSnapshot: {
          'quest': {
            'id': quest.id,
            'targetDate': quest.targetDate?.toIso8601String(),
          },
          'missions': [
            for (final mission in missions)
              {
                'id': mission.id,
                'title': mission.title,
                'status': mission.status.storageKey,
                'progressPercent': mission.progressPercent,
                'sortOrder': mission.sortOrder,
                'isToday': mission.isToday,
                'routeState': mission.routeState.name,
              },
          ],
        },
      ),
    );
  }
}
