import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:uuid/uuid.dart';

import 'quest_safety_service.dart';

const _uuid = Uuid();

class AbuseSignal {
  AbuseSignal({
    String? id,
    required this.userId,
    required this.category,
    required this.severity,
    required this.confidence,
    required this.reasonCode,
    required this.policyVersion,
    required this.sourceType,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final QuestSafetyCategory category;
  final int severity;
  final double confidence;
  final String reasonCode;
  final String policyVersion;
  final String sourceType;
  final DateTime createdAt;
}

abstract interface class AbuseSignalRepository {
  Future<void> record(AbuseSignal signal);
}

class InMemoryAbuseSignalRepository implements AbuseSignalRepository {
  final List<AbuseSignal> signals = [];

  @override
  Future<void> record(AbuseSignal signal) async => signals.add(signal);
}

class SupabaseAbuseSignalRepository implements AbuseSignalRepository {
  const SupabaseAbuseSignalRepository(this.client);

  final SupabaseClient client;

  @override
  Future<void> record(AbuseSignal signal) async {
    await client.from('abuse_signals').insert({
      'id': signal.id,
      'user_id': signal.userId,
      'category': signal.category.name,
      'severity': signal.severity,
      'confidence': signal.confidence,
      'reason_code': signal.reasonCode,
      'policy_version': signal.policyVersion,
      'source_type': signal.sourceType,
      'created_at': signal.createdAt.toIso8601String(),
    });
  }
}
