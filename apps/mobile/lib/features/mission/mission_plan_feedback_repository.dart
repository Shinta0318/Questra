import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'mission_plan_feedback.dart';

final missionPlanFeedbackRepositoryProvider =
    Provider<MissionPlanFeedbackRepository>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseMissionPlanFeedbackRepository(Supabase.instance.client);
      }
      return InMemoryMissionPlanFeedbackRepository();
    });

abstract interface class MissionPlanFeedbackRepository {
  Future<void> save(MissionPlanFeedback feedback);
}

class InMemoryMissionPlanFeedbackRepository
    implements MissionPlanFeedbackRepository {
  final List<MissionPlanFeedback> values = [];

  @override
  Future<void> save(MissionPlanFeedback feedback) async {
    values.add(feedback);
  }
}

class SupabaseMissionPlanFeedbackRepository
    implements MissionPlanFeedbackRepository {
  const SupabaseMissionPlanFeedbackRepository(this.client);

  final SupabaseClient client;

  @override
  Future<void> save(MissionPlanFeedback feedback) async {
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('ログインが必要です。');
    await client
        .from('mission_plan_feedback')
        .insert(feedback.toInsert(ownerId));
  }
}
