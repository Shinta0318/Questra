import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import 'quest_lifecycle_stage.dart';

const _stageUuid = Uuid();

abstract interface class QuestStageRepository {
  Future<QuestLifecycleStage?> find(String questId);
  Future<void> setStage(String questId, QuestStageDecision decision);
}

class InMemoryQuestStageRepository implements QuestStageRepository {
  final Map<String, QuestLifecycleStage> values = {};
  @override
  Future<QuestLifecycleStage?> find(String questId) async => values[questId];
  @override
  Future<void> setStage(String questId, QuestStageDecision decision) async =>
      values[questId] = decision.stage;
}

class SupabaseQuestStageRepository implements QuestStageRepository {
  const SupabaseQuestStageRepository(this.client);
  final SupabaseClient client;
  @override
  Future<QuestLifecycleStage?> find(String questId) async {
    final row = await client
        .from('quest_stage_state')
        .select('current_stage')
        .eq('quest_id', questId)
        .maybeSingle();
    final key = row?['current_stage'] as String?;
    return key == null
        ? null
        : QuestLifecycleStage.values
              .where((stage) => stage.storageKey == key)
              .firstOrNull;
  }

  @override
  Future<void> setStage(String questId, QuestStageDecision decision) async {
    await client.rpc<void>(
      'set_quest_lifecycle_stage',
      params: {
        'p_quest_id': questId,
        'p_next_stage': decision.stage.storageKey,
        'p_source': decision.source.name,
        'p_confidence': decision.confidence,
        'p_reason_code': decision.reasonCode,
        'p_idempotency_key':
            'stage:$questId:${decision.stage.storageKey}:${_stageUuid.v4()}',
      },
    );
  }
}

final questStageRepositoryProvider = Provider<QuestStageRepository>(
  (ref) => SupabaseConfig.isConfigured
      ? SupabaseQuestStageRepository(Supabase.instance.client)
      : InMemoryQuestStageRepository(),
);
final questStageProvider = FutureProvider.family<QuestLifecycleStage?, String>(
  (ref, questId) => ref.watch(questStageRepositoryProvider).find(questId),
);
