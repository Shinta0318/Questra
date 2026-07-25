import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import '../../core/estimation/effort_estimate.dart';
import 'mission_model.dart';

const _missionColumns =
    'id,quest_id,title,description,guide_type,difficulty,status,progress_percent,sort_order,is_today,effort_estimate,parent_mission_id,dependency_ids,priority,category,estimated_cost_label,reference_hints,enterprise_support_hints,difficulty_score,estimated_duration_days,route_state,created_at,quests!inner(title)';

abstract interface class MissionRepository {
  Future<List<Mission>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  });
  Future<List<Mission>> findManyByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  });
  Future<Mission> save(Mission mission);
  Future<void> delete(String missionId);
}

class InMemoryMissionRepository implements MissionRepository {
  final List<Mission> _missions = [];

  @override
  Future<List<Mission>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  }) async {
    final missions = _missions
        .where(
          (mission) =>
              mission.questId == questId &&
              mission.routeState != MissionRouteState.removed,
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return missions.take(limit).toList(growable: false);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  }) async {
    final questIdSet = questIds.toSet();
    final missions = _missions
        .where(
          (mission) =>
              questIdSet.contains(mission.questId) &&
              mission.routeState != MissionRouteState.removed,
        )
        .toList()
      ..sort((a, b) {
        final questOrder = a.questId.compareTo(b.questId);
        return questOrder != 0
            ? questOrder
            : a.sortOrder.compareTo(b.sortOrder);
      });
    return missions.take(limit).toList(growable: false);
  }

  @override
  Future<Mission> save(Mission mission) async {
    _missions.removeWhere((current) => current.id == mission.id);
    _missions.insert(0, mission);
    return mission;
  }

  @override
  Future<void> delete(String missionId) async {
    _missions.removeWhere((mission) => mission.id == missionId);
  }
}

class SupabaseMissionRepository implements MissionRepository {
  const SupabaseMissionRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<Mission>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  }) async {
    final rows = await client
        .from('missions')
        .select(_missionColumns)
        .eq('quest_id', questId)
        .neq('route_state', 'removed')
        .order('sort_order')
        .limit(limit);

    return rows
        .map((row) => _missionFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  }) async {
    if (questIds.isEmpty) {
      return [];
    }

    final rows = await client
        .from('missions')
        .select(_missionColumns)
        .inFilter('quest_id', questIds)
        .neq('route_state', 'removed')
        .order('quest_id')
        .order('sort_order')
        .limit(limit);

    return rows
        .map((row) => _missionFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Mission> save(Mission mission) async {
    final rows = await client
        .from('missions')
        .upsert(_missionToRow(mission))
        .select(_missionColumns)
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Mission was not saved.');
    }

    return _missionFromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> delete(String missionId) async {
    await client.from('missions').delete().eq('id', missionId);
  }

  Map<String, Object?> _missionToRow(Mission mission) {
    return {
      'id': mission.id,
      'quest_id': mission.questId,
      'title': mission.title,
      'description': mission.description,
      'guide_type': mission.guideType.storageKey,
      'difficulty': mission.difficulty.storageKey,
      'status': mission.status.storageKey,
      'progress_percent': mission.progressPercent.clamp(0, 100),
      'sort_order': mission.sortOrder,
      'is_today': mission.isToday,
      'effort_estimate': mission.effortEstimate == null
          ? null
          : effortEstimateToJson(mission.effortEstimate!),
      'parent_mission_id': mission.parentMissionId,
      'dependency_ids': mission.dependencyIds,
      'priority': mission.priority.storageKey,
      'category': mission.category,
      'estimated_cost_label': mission.estimatedCostLabel,
      'reference_hints': mission.referenceHints,
      'enterprise_support_hints': mission.enterpriseSupportHints,
      'difficulty_score': mission.difficultyScore,
      'estimated_duration_days': mission.estimatedDurationDays,
      'route_state': mission.routeState.name,
      'completed_at': mission.status == MissionStatus.completed
          ? DateTime.now().toIso8601String()
          : null,
      'created_at': mission.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Mission _missionFromRow(Map<String, dynamic> row) {
    final questData = row['quests'];
    final questTitle = questData is Map
        ? questData['title'] as String?
        : row['quest_title'] as String?;
    return Mission(
      id: row['id'] as String,
      questId: row['quest_id'] as String,
      questTitle: questTitle ?? 'このQuest',
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      guideType: guideTypeFromStorage(row['guide_type'] as String),
      difficulty: missionDifficultyFromStorage(row['difficulty'] as String),
      status: missionStatusFromStorage(row['status'] as String),
      progressPercent: row['progress_percent'] as int? ??
          ((row['status'] as String) == 'completed' ? 100 : 0),
      sortOrder: row['sort_order'] as int? ?? 0,
      isToday: row['is_today'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      effortEstimate: effortEstimateFromJson(row['effort_estimate']),
      parentMissionId: row['parent_mission_id'] as String?,
      dependencyIds: _stringList(row['dependency_ids']),
      priority: missionPriorityFromStorage(
        row['priority'] as String? ?? 'normal',
      ),
      category: row['category'] as String? ?? '実行',
      estimatedCostLabel: row['estimated_cost_label'] as String?,
      referenceHints: _stringList(row['reference_hints']),
      enterpriseSupportHints: _stringList(row['enterprise_support_hints']),
      difficultyScore: row['difficulty_score'] as int?,
      estimatedDurationDays: row['estimated_duration_days'] as int?,
      routeState: missionRouteStateFromStorage(
        row['route_state'] as String? ?? 'active',
      ),
    );
  }

  List<String> _stringList(Object? value) =>
      (value as List?)?.whereType<String>().toList(growable: false) ?? const [];
}
