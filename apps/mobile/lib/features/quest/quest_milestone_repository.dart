import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'quest_guide_model.dart';
import 'quest_milestone_model.dart';

abstract interface class QuestMilestoneRepository {
  Future<List<QuestMilestone>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.questListLimit,
  });
  Future<QuestMilestone> save({
    required String ownerId,
    required QuestMilestone milestone,
  });
  Future<List<QuestMilestone>> saveAll({
    required String ownerId,
    required List<QuestMilestone> milestones,
  });
}

class InMemoryQuestMilestoneRepository implements QuestMilestoneRepository {
  final List<_OwnedQuestMilestone> _milestones = [];

  @override
  Future<List<QuestMilestone>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.questListLimit,
  }) async {
    final questIdSet = questIds.toSet();
    return _milestones
        .where((entry) => questIdSet.contains(entry.milestone.questId))
        .map((entry) => entry.milestone)
        .take(limit)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<QuestMilestone> save({
    required String ownerId,
    required QuestMilestone milestone,
  }) async {
    _milestones.removeWhere((entry) => entry.milestone.id == milestone.id);
    _milestones.add(_OwnedQuestMilestone(ownerId, milestone));
    return milestone;
  }

  @override
  Future<List<QuestMilestone>> saveAll({
    required String ownerId,
    required List<QuestMilestone> milestones,
  }) async {
    final saved = <QuestMilestone>[];
    for (final milestone in milestones) {
      saved.add(await save(ownerId: ownerId, milestone: milestone));
    }
    return saved;
  }
}

class SupabaseQuestMilestoneRepository implements QuestMilestoneRepository {
  const SupabaseQuestMilestoneRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<QuestMilestone>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.questListLimit,
  }) async {
    if (questIds.isEmpty) {
      return const [];
    }

    final rows = await client
        .from('quest_milestones')
        .select(
          'id,quest_id,title,description,status,progress,sort_order,guide_type',
        )
        .inFilter('quest_id', questIds)
        .order('sort_order')
        .limit(limit);

    return rows
        .map((row) => _milestoneFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<QuestMilestone> save({
    required String ownerId,
    required QuestMilestone milestone,
  }) async {
    final rows = await client
        .from('quest_milestones')
        .upsert(_milestoneToRow(ownerId, milestone))
        .select(
          'id,quest_id,title,description,status,progress,sort_order,guide_type',
        )
        .limit(1);

    if (rows.isEmpty) {
      throw StateError('Quest Milestone was not saved.');
    }

    return _milestoneFromRow(Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<List<QuestMilestone>> saveAll({
    required String ownerId,
    required List<QuestMilestone> milestones,
  }) async {
    if (milestones.isEmpty) {
      return const [];
    }

    final rows = await client
        .from('quest_milestones')
        .upsert(
          milestones
              .map((milestone) => _milestoneToRow(ownerId, milestone))
              .toList(growable: false),
        )
        .select(
          'id,quest_id,title,description,status,progress,sort_order,guide_type',
        )
        .order('sort_order');

    return rows
        .map((row) => _milestoneFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Map<String, Object?> _milestoneToRow(
    String ownerId,
    QuestMilestone milestone,
  ) {
    return {
      'id': milestone.id,
      'owner_id': ownerId,
      'quest_id': milestone.questId,
      'title': milestone.title,
      'description': milestone.description,
      'status': milestone.status.storageKey,
      'progress': milestone.progress,
      'sort_order': milestone.sortOrder,
      'guide_type': milestone.guideType?.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  QuestMilestone _milestoneFromRow(Map<String, dynamic> row) {
    final guideType = row['guide_type'] as String?;
    return QuestMilestone(
      id: row['id'] as String,
      questId: row['quest_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      status: questMilestoneStatusFromStorage(row['status'] as String),
      progress: (row['progress'] as num?)?.toDouble() ?? 0,
      sortOrder: row['sort_order'] as int? ?? 0,
      guideType: guideType == null
          ? null
          : GuideType.values.firstWhere(
              (type) => type.name == guideType,
              orElse: () => GuideType.route,
            ),
    );
  }
}

class _OwnedQuestMilestone {
  const _OwnedQuestMilestone(this.ownerId, this.milestone);

  final String ownerId;
  final QuestMilestone milestone;
}
