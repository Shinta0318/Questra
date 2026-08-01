import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import '../../core/estimation/effort_estimate.dart';
import 'quest_model.dart';
import 'quest_dna.dart';
import 'quest_evaluation.dart';
import 'quest_understanding.dart';
import 'mission_plan_quality.dart';

const _questColumns =
    'id,title,description,difficulty,status,visibility,target_date,'
    'requested_target_month,effort_estimate,quest_evaluation,'
    'difficulty_score,estimated_duration_days,estimated_cost,'
    'estimated_success_rate,estimated_mission_count,evaluation_version,'
    'evaluated_at,recommended_start_date,risk_summary,quest_dna,'
    'quest_dna_version,quest_dna_evaluated_at,quest_understanding,plan_quality,progress,created_at';

abstract interface class QuestRepository {
  Future<List<Quest>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.questListLimit,
  });
  Future<Quest> save({required String ownerId, required Quest quest});
  Future<void> delete({required String ownerId, required String questId});
}

class InMemoryQuestRepository implements QuestRepository {
  final List<_OwnedQuest> _quests = [];

  @override
  Future<List<Quest>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.questListLimit,
  }) async {
    return _quests
        .where((entry) => entry.ownerId == userId)
        .map((entry) => entry.quest)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    _quests.removeWhere((entry) => entry.quest.id == quest.id);
    _quests.add(_OwnedQuest(ownerId: ownerId, quest: quest));
    return quest;
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String questId,
  }) async {
    _quests.removeWhere(
      (entry) => entry.ownerId == ownerId && entry.quest.id == questId,
    );
  }
}

class SupabaseQuestRepository implements QuestRepository {
  const SupabaseQuestRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Quest>> findByUser(
    String userId, {
    int limit = QuestraPerformanceLimits.questListLimit,
  }) async {
    final rows = await client
        .from('quests')
        .select(_questColumns)
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map((row) => _questFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Quest> save({required String ownerId, required Quest quest}) async {
    final rows = await client
        .from('quests')
        .upsert(_questToRow(ownerId, quest))
        .select(_questColumns)
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Quest was not saved.');
    }

    return _questFromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> delete({
    required String ownerId,
    required String questId,
  }) async {
    await client
        .from('quests')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', questId);
  }

  Map<String, Object?> _questToRow(String ownerId, Quest quest) {
    return {
      'id': quest.id,
      'owner_id': ownerId,
      'title': quest.title,
      'description': quest.description,
      'difficulty': quest.difficulty.storageKey,
      'status': quest.status.storageKey,
      'visibility': quest.visibility.storageKey,
      'target_date': quest.targetDate?.toIso8601String().split('T').first,
      'requested_target_month': quest.targetDate == null
          ? null
          : '${quest.targetDate!.year.toString().padLeft(4, '0')}-${quest.targetDate!.month.toString().padLeft(2, '0')}-01',
      'effort_estimate': quest.effortEstimate == null
          ? null
          : effortEstimateToJson(quest.effortEstimate!),
      'quest_evaluation': quest.evaluation?.toJson(),
      'quest_dna': quest.dna?.toJson(),
      'quest_dna_version': quest.dna?.version,
      'quest_dna_evaluated_at': quest.dna?.evaluatedAt.toIso8601String(),
      'quest_understanding': quest.understanding?.toJson(),
      'plan_quality': quest.planQuality?.toJson(),
      'difficulty_score': quest.evaluation?.difficultyScore,
      'estimated_duration_days': quest.evaluation?.estimatedDurationDays,
      'estimated_cost': quest.evaluation?.estimatedCostLabel,
      'estimated_success_rate': quest.evaluation?.successLikelihood,
      'estimated_mission_count': quest.evaluation?.estimatedMissionCount,
      'evaluation_version': quest.evaluation?.version,
      'evaluated_at': quest.evaluation?.evaluatedAt.toIso8601String(),
      'recommended_start_date': quest.evaluation?.recommendedStartDate
          ?.toIso8601String()
          .split('T')
          .first,
      'risk_summary': quest.evaluation?.riskSummary,
      'progress': quest.progress.clamp(0, 1),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Quest _questFromRow(Map<String, dynamic> row) {
    return Quest(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      difficulty: questDifficultyFromStorage(row['difficulty'] as String),
      status: questStatusFromStorage(row['status'] as String),
      visibility: questVisibilityFromStorage(row['visibility'] as String),
      targetDate: row['requested_target_month'] != null
          ? DateTime.parse(row['requested_target_month'] as String)
          : row['target_date'] == null
          ? null
          : DateTime.parse(row['target_date'] as String),
      effortEstimate: effortEstimateFromJson(row['effort_estimate']),
      evaluation: QuestEvaluation.fromJson(row['quest_evaluation']),
      dna: QuestDna.fromJson(row['quest_dna']),
      understanding: QuestUnderstanding.fromJson(row['quest_understanding']),
      planQuality: MissionPlanQuality.fromJson(row['plan_quality']),
      progress: (row['progress'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _OwnedQuest {
  const _OwnedQuest({required this.ownerId, required this.quest});

  final String ownerId;
  final Quest quest;
}
