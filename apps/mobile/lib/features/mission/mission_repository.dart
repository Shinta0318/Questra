import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'mission_model.dart';

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
    final missions =
        _missions.where((mission) => mission.questId == questId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return missions.take(limit).toList(growable: false);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.missionListLimit,
  }) async {
    final questIdSet = questIds.toSet();
    final missions =
        _missions
            .where((mission) => questIdSet.contains(mission.questId))
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
        .select(
          'id,quest_id,title,description,guide_type,difficulty,status,sort_order,is_today,created_at',
        )
        .eq('quest_id', questId)
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
        .select(
          'id,quest_id,title,description,guide_type,difficulty,status,sort_order,is_today,created_at',
        )
        .inFilter('quest_id', questIds)
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
        .select(
          'id,quest_id,title,description,guide_type,difficulty,status,sort_order,is_today,created_at',
        )
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
      'sort_order': mission.sortOrder,
      'is_today': mission.isToday,
      'completed_at': mission.status == MissionStatus.completed
          ? DateTime.now().toIso8601String()
          : null,
      'created_at': mission.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Mission _missionFromRow(Map<String, dynamic> row) {
    return Mission(
      id: row['id'] as String,
      questId: row['quest_id'] as String,
      questTitle: row['quest_title'] as String? ?? 'Quest',
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      guideType: guideTypeFromStorage(row['guide_type'] as String),
      difficulty: missionDifficultyFromStorage(row['difficulty'] as String),
      status: missionStatusFromStorage(row['status'] as String),
      sortOrder: row['sort_order'] as int? ?? 0,
      isToday: row['is_today'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
