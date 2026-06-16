import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'mission_model.dart';

abstract interface class MissionRepository {
  Future<List<Mission>> findByQuest(String questId);
  Future<List<Mission>> findManyByQuestIds(List<String> questIds);
  Future<Mission> save(Mission mission);
  Future<void> delete(String missionId);
}

class InMemoryMissionRepository implements MissionRepository {
  final List<Mission> _missions = [];

  @override
  Future<List<Mission>> findByQuest(String questId) async {
    return _missions
        .where((mission) => mission.questId == questId)
        .toList(growable: false);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(List<String> questIds) async {
    final questIdSet = questIds.toSet();
    return _missions
        .where((mission) => questIdSet.contains(mission.questId))
        .toList(growable: false);
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
  Future<List<Mission>> findByQuest(String questId) async {
    final rows = await client
        .from('missions')
        .select()
        .eq('quest_id', questId)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _missionFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<Mission>> findManyByQuestIds(List<String> questIds) async {
    if (questIds.isEmpty) {
      return [];
    }

    final rows = await client
        .from('missions')
        .select()
        .inFilter('quest_id', questIds)
        .order('created_at', ascending: false);

    return rows
        .map((row) => _missionFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Mission> save(Mission mission) async {
    final rows = await client
        .from('missions')
        .upsert(_missionToRow(mission))
        .select()
        .limit(1);

    if (rows.isEmpty) {
      return mission;
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
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
