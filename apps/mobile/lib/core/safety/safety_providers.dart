import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../config/supabase_config.dart';
import 'abuse_signal_repository.dart';
import 'quest_safety_service.dart';

final questSafetyServiceProvider = Provider<QuestSafetyService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseQuestSafetyService(client: Supabase.instance.client);
  }
  return const LocalQuestSafetyService();
});

final abuseSignalRepositoryProvider = Provider<AbuseSignalRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAbuseSignalRepository(Supabase.instance.client);
  }
  return InMemoryAbuseSignalRepository();
});

final safetySignalRecorderProvider = Provider<SafetySignalRecorder>((ref) {
  return SafetySignalRecorder(ref.watch(abuseSignalRepositoryProvider));
});

class SafetySignalRecorder {
  const SafetySignalRecorder(this.repository);

  final AbuseSignalRepository repository;

  Future<void> record({
    required String? userId,
    required QuestSafetyAssessment assessment,
  }) async {
    if (!assessment.shouldRecordSignal || userId == null) return;
    try {
      await repository.record(
        AbuseSignal(
          userId: userId,
          category: assessment.category,
          severity: assessment.severity,
          confidence: assessment.confidence,
          reasonCode: assessment.reasonCode,
          policyVersion: assessment.policyVersion,
          sourceType: assessment.sourceType,
        ),
      );
    } catch (_) {
      // Safety response remains authoritative even if audit persistence fails.
    }
  }
}
