import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../quest/quest_model.dart';
import '../quest/route_replanning_model.dart';
import 'mission_model.dart';
import 'mission_regeneration_intent.dart';

final missionRegenerationProposalServiceProvider =
    Provider<MissionRegenerationProposalService>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseMissionRegenerationProposalService(
          Supabase.instance.client,
        );
      }
      return const LocalMissionRegenerationProposalService();
    });

abstract interface class MissionRegenerationProposalService {
  Future<RouteChangeProposal> propose({
    required Quest quest,
    required Mission mission,
    required MissionRegenerationIntent intent,
  });
}

class LocalMissionRegenerationProposalService
    implements MissionRegenerationProposalService {
  const LocalMissionRegenerationProposalService();

  @override
  Future<RouteChangeProposal> propose({
    required Quest quest,
    required Mission mission,
    required MissionRegenerationIntent intent,
  }) async {
    if (mission.status == MissionStatus.completed) {
      throw StateError('完了済みMissionは変更できません。');
    }
    final hint = MissionRegenerationService.promptHint(
      MissionRegenerationRequest(mission: mission, intent: intent),
    );
    final after = _replacement(mission, intent);
    return _proposal(
      quest: quest,
      mission: mission,
      intent: intent,
      reason: hint,
      after: after,
      confidence: 0.64,
    );
  }

  static Map<String, Object?> _replacement(
    Mission mission,
    MissionRegenerationIntent intent,
  ) {
    final title = switch (intent) {
      MissionRegenerationIntent.smaller => '${mission.title}を15分だけ始める',
      MissionRegenerationIntent.lowerBudget => '${mission.title}の無料・低費用案を比較する',
      MissionRegenerationIntent.beginnerFriendly =>
        '${mission.title}の基礎を1つ確認する',
      MissionRegenerationIntent.clarifyDoneCondition => mission.title,
      MissionRegenerationIntent.harder => '${mission.title}の成果基準を一段上げる',
      MissionRegenerationIntent.selfManaged => '${mission.title}を自分で進める手順を作る',
      MissionRegenerationIntent.alternative => '${mission.title}の別ルートを試す',
      MissionRegenerationIntent.fitDeadline => '${mission.title}の必須部分に絞る',
      MissionRegenerationIntent.removeUnneeded => mission.title,
      MissionRegenerationIntent.reorder => mission.title,
      MissionRegenerationIntent.moreSpecific => '${mission.title}の対象と日時を決める',
    };
    final doneCondition = switch (intent) {
      MissionRegenerationIntent.smaller => '15分取り組み、次に続ける点を1つ記録する',
      MissionRegenerationIntent.lowerBudget => '費用と条件を比較した候補を1つ記録する',
      MissionRegenerationIntent.beginnerFriendly => '基礎情報を1つ確認し、自分の言葉で要点を記録する',
      MissionRegenerationIntent.clarifyDoneCondition =>
        mission.doneCondition.isEmpty
            ? '確認できる成果を1つ記録する'
            : mission.doneCondition,
      _ =>
        mission.doneCondition.isEmpty
            ? '実行結果を確認できる形で記録する'
            : mission.doneCondition,
    };
    return {
      'title': title,
      'description': '$doneConditionしたら完了です。',
      'doneCondition': doneCondition,
      'expectedOutput': mission.expectedOutput.isEmpty
          ? '確認できる実行記録'
          : mission.expectedOutput,
      'estimatedDurationDays': intent == MissionRegenerationIntent.smaller
          ? 1
          : mission.estimatedDurationDays,
      'difficultyScore': intent == MissionRegenerationIntent.harder
          ? ((mission.difficultyScore ?? 2) + 1).clamp(1, 5)
          : mission.difficultyScore,
      'sourceRequirement': mission.sourceRequirement,
      'confidence': 0.64,
    };
  }
}

class SupabaseMissionRegenerationProposalService
    implements MissionRegenerationProposalService {
  const SupabaseMissionRegenerationProposalService(this.client);

  final SupabaseClient client;

  @override
  Future<RouteChangeProposal> propose({
    required Quest quest,
    required Mission mission,
    required MissionRegenerationIntent intent,
  }) async {
    if (mission.status == MissionStatus.completed) {
      throw StateError('完了済みMissionは変更できません。');
    }
    try {
      final response = await client.functions.invoke(
        'arc-quest-guide',
        body: {
          'mode': 'regenerate_mission',
          'quest': {
            'id': quest.id,
            'title': quest.title,
            'description': quest.description,
            'target_date': quest.targetDate?.toIso8601String(),
          },
          'mission': _missionData(mission),
          'regeneration_intent': intent.name,
        },
      );
      if (response.status < 200 ||
          response.status >= 300 ||
          response.data is! Map) {
        throw const MissionRegenerationUnavailableException();
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      final replacement = data['mission_candidate'];
      if (replacement is! Map) {
        throw const MissionRegenerationUnavailableException();
      }
      final after = Map<String, dynamic>.from(replacement);
      return _proposal(
        quest: quest,
        mission: mission,
        intent: intent,
        reason:
            data['reason'] as String? ??
            MissionRegenerationService.promptHint(
              MissionRegenerationRequest(mission: mission, intent: intent),
            ),
        after: {
          'title': after['title'],
          'description': after['description'],
          'doneCondition': after['done_condition'],
          'expectedOutput': after['expected_output'],
          'estimatedDurationDays': after['estimated_duration_days'],
          'difficultyScore': after['difficulty_score'],
          'sourceRequirement': after['source_requirement'],
          'confidence': after['confidence'],
        },
        confidence:
            (after['confidence'] as num?)?.toDouble().clamp(0, 1) ?? 0.6,
      );
    } on MissionRegenerationUnavailableException {
      rethrow;
    } catch (_) {
      throw const MissionRegenerationUnavailableException();
    }
  }
}

class MissionRegenerationUnavailableException implements Exception {
  const MissionRegenerationUnavailableException();

  @override
  String toString() =>
      'ArcがMissionを描き直せませんでした。元のMissionは変更されていません。もう一度試してください。';
}

RouteChangeProposal _proposal({
  required Quest quest,
  required Mission mission,
  required MissionRegenerationIntent intent,
  required String reason,
  required Map<String, Object?> after,
  required double confidence,
}) {
  return const RouteProposalValidator().validate(
    RouteChangeProposal(
      questId: quest.id,
      reason: RouteProposalReason.manualReview,
      summary: '「${mission.title}」を「${intent.label}」の方針で描き直します。',
      confidence: confidence,
      routeSnapshot: {
        'quest': {'id': quest.id},
        'missions': [],
      },
      items: [
        RouteChangeItem(
          action: RouteChangeAction.replace,
          targetMissionId: mission.id,
          title: 'Missionを描き直す',
          reason: reason,
          safetyLevel: 3,
          beforeData: {
            'title': mission.title,
            'description': mission.description,
            'doneCondition': mission.doneCondition,
            'expectedOutput': mission.expectedOutput,
            'estimatedDurationDays': mission.estimatedDurationDays,
            'difficultyScore': mission.difficultyScore,
            'sourceRequirement': mission.sourceRequirement,
            'confidence': mission.confidence,
          },
          afterData: after,
        ),
      ],
    ),
  );
}

Map<String, Object?> _missionData(Mission mission) => {
  'id': mission.id,
  'title': mission.title,
  'description': mission.description,
  'done_condition': mission.doneCondition,
  'expected_output': mission.expectedOutput,
  'estimated_duration_days': mission.estimatedDurationDays,
  'difficulty_score': mission.difficultyScore,
  'source_requirement': mission.sourceRequirement,
  'dependency_ids': mission.dependencyIds,
};
