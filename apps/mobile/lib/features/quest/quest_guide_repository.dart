import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'quest_guide_model.dart';

abstract interface class QuestGuideRepository {
  Future<List<QuestGuide>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.questGuideLimit,
  });
  Future<List<QuestGuide>> saveAll(List<QuestGuide> guides);
}

class InMemoryQuestGuideRepository implements QuestGuideRepository {
  final List<QuestGuide> _guides = [];

  @override
  Future<List<QuestGuide>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.questGuideLimit,
  }) async {
    return _guides
        .where((guide) => guide.questId == questId)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<QuestGuide>> saveAll(List<QuestGuide> guides) async {
    final guideIds = guides.map((guide) => guide.id).toSet();
    _guides.removeWhere((guide) => guideIds.contains(guide.id));
    _guides.addAll(guides);
    return guides;
  }
}

class SupabaseQuestGuideRepository implements QuestGuideRepository {
  const SupabaseQuestGuideRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<QuestGuide>> findByQuest(
    String questId, {
    int limit = QuestraPerformanceLimits.questGuideLimit,
  }) async {
    final rows = await client
        .from('quest_guides')
        .select('id,quest_id,guide_type,title,description,suggested_actions')
        .eq('quest_id', questId)
        .order('created_at')
        .limit(limit);

    return rows
        .map((row) => _guideFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<QuestGuide>> saveAll(List<QuestGuide> guides) async {
    if (guides.isEmpty) {
      return guides;
    }

    final rows = await client
        .from('quest_guides')
        .upsert(guides.map(_guideToRow).toList())
        .select('id,quest_id,guide_type,title,description,suggested_actions');

    return rows
        .map((row) => _guideFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Map<String, Object?> _guideToRow(QuestGuide guide) {
    return {
      'id': guide.id,
      'quest_id': guide.questId,
      'guide_type': guide.guideType.name,
      'title': guide.title,
      'description': guide.description,
      'suggested_actions': guide.suggestedActions,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  QuestGuide _guideFromRow(Map<String, dynamic> row) {
    return QuestGuide(
      id: row['id'] as String,
      questId: row['quest_id'] as String,
      guideType: GuideType.values.firstWhere(
        (guideType) => guideType.name == row['guide_type'],
        orElse: () => GuideType.route,
      ),
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      suggestedActions:
          (row['suggested_actions'] as List?)?.cast<String>() ?? const [],
    );
  }
}
