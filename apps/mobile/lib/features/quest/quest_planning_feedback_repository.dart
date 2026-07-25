import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class QuestPlanningFeedback {
  const QuestPlanningFeedback({
    required this.questId,
    required this.categoryKey,
    required this.sourceType,
    required this.generatedCount,
    required this.acceptedCount,
    required this.editedCount,
    required this.targetWindow,
  });

  final String questId;
  final String categoryKey;
  final String sourceType;
  final int generatedCount;
  final int acceptedCount;
  final int editedCount;
  final String targetWindow;
}

abstract interface class QuestPlanningFeedbackRepository {
  Future<void> save(QuestPlanningFeedback feedback);
}

class InMemoryQuestPlanningFeedbackRepository
    implements QuestPlanningFeedbackRepository {
  final List<QuestPlanningFeedback> feedback = [];

  @override
  Future<void> save(QuestPlanningFeedback value) async {
    feedback.add(value);
  }
}

class SupabaseQuestPlanningFeedbackRepository
    implements QuestPlanningFeedbackRepository {
  const SupabaseQuestPlanningFeedbackRepository(this.client);

  final SupabaseClient client;

  @override
  Future<void> save(QuestPlanningFeedback feedback) async {
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) return;
    await client.from('quest_planning_feedback').insert({
      'owner_id': ownerId,
      'quest_id': feedback.questId,
      'category_key': feedback.categoryKey,
      'source_type': feedback.sourceType,
      'generated_count': feedback.generatedCount,
      'accepted_count': feedback.acceptedCount,
      'edited_count': feedback.editedCount,
      'target_window': feedback.targetWindow,
    });
  }
}

String questTargetWindow(DateTime? targetDate, DateTime now) {
  if (targetDate == null) return 'unspecified';
  final days = targetDate.difference(now).inDays;
  if (days <= 30) return 'within_30_days';
  if (days <= 90) return 'within_90_days';
  if (days <= 365) return 'within_1_year';
  return 'over_1_year';
}
