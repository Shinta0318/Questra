import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'guild_discovery_model.dart';

abstract interface class GuildDiscoveryRepository {
  Future<GuildPilotStatus> pilotStatus();

  Future<List<GuildDiscoveryQuest>> findApprovedPublic({
    int limit = 20,
    DateTime? beforePublishedAt,
    String? beforeId,
  });

  Future<String> publishQuest({
    required String questId,
    required String summary,
    required List<String> tags,
    required GuildDiscoveryVisibility visibility,
    bool seekingCompanions = false,
  });

  Future<String> publishMission({
    required String publicationId,
    required String missionId,
    required String purpose,
    required List<String> tags,
  });

  Future<void> unpublishQuest(String publicationId);

  Future<void> recordCopy({
    required String publicationId,
    required String destinationQuestId,
    required GuildQuestCopyOptions options,
    required String idempotencyKey,
  });

  Future<GuildQuestCopyResult> copyToPrivate({
    required String publicationId,
    required GuildQuestCopyOptions options,
    required String idempotencyKey,
  });

  Future<void> recordDiscoveryOpened({
    required String publicationId,
    required String eventKey,
  });
}

class SupabaseGuildDiscoveryRepository implements GuildDiscoveryRepository {
  const SupabaseGuildDiscoveryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<GuildPilotStatus> pilotStatus() async {
    final result = await client.rpc('get_guild_pilot_status');
    final row = Map<String, dynamic>.from(result as Map);
    return GuildPilotStatus(
      configured: row['configured'] as bool? ?? true,
      enabled: row['enabled'] as bool? ?? false,
      cohort: row['cohort'] as String?,
    );
  }

  @override
  Future<List<GuildDiscoveryQuest>> findApprovedPublic({
    int limit = 20,
    DateTime? beforePublishedAt,
    String? beforeId,
  }) async {
    if (limit <= 0) return const <GuildDiscoveryQuest>[];
    final safeLimit = limit.clamp(1, 50);
    if ((beforePublishedAt == null) != (beforeId == null)) {
      throw ArgumentError('Guild cursor requires both timestamp and id.');
    }
    final rows =
        await client.rpc(
              'list_guild_pilot_quests',
              params: {
                'p_limit': safeLimit,
                'p_before_published_at': beforePublishedAt
                    ?.toUtc()
                    .toIso8601String(),
                'p_before_id': beforeId,
              },
            )
            as List;

    return rows
        .map((row) => _questFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<String> publishQuest({
    required String questId,
    required String summary,
    required List<String> tags,
    required GuildDiscoveryVisibility visibility,
    bool seekingCompanions = false,
  }) async {
    if (visibility == GuildDiscoveryVisibility.private) {
      throw ArgumentError.value(visibility, 'visibility', '公開範囲を選んでください。');
    }
    final result = await client.rpc(
      'publish_guild_quest',
      params: {
        'p_quest_id': questId,
        'p_summary': summary.trim(),
        'p_tags': _boundedTags(tags),
        'p_visibility': visibility.name,
        'p_seeking_companions': seekingCompanions,
      },
    );
    return result as String;
  }

  @override
  Future<String> publishMission({
    required String publicationId,
    required String missionId,
    required String purpose,
    required List<String> tags,
  }) async {
    final result = await client.rpc(
      'publish_guild_mission',
      params: {
        'p_publication_id': publicationId,
        'p_mission_id': missionId,
        'p_purpose': purpose.trim(),
        'p_tags': _boundedTags(tags),
      },
    );
    return result as String;
  }

  @override
  Future<void> unpublishQuest(String publicationId) async {
    await client.rpc(
      'unpublish_guild_quest',
      params: {'p_publication_id': publicationId},
    );
  }

  @override
  Future<void> recordCopy({
    required String publicationId,
    required String destinationQuestId,
    required GuildQuestCopyOptions options,
    required String idempotencyKey,
  }) async {
    await client.rpc(
      'record_guild_quest_copy',
      params: {
        'p_publication_id': publicationId,
        'p_destination_quest_id': destinationQuestId,
        'p_include_missions': options.includeMissions,
        'p_arc_optimization_requested': options.optimizeWithArc,
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  @override
  Future<GuildQuestCopyResult> copyToPrivate({
    required String publicationId,
    required GuildQuestCopyOptions options,
    required String idempotencyKey,
  }) async {
    final result = await client.rpc(
      'copy_guild_quest_to_private',
      params: {
        'p_publication_id': publicationId,
        'p_include_missions': options.includeMissions,
        'p_arc_optimization_requested': options.optimizeWithArc,
        'p_idempotency_key': idempotencyKey,
      },
    );
    final row = Map<String, dynamic>.from(result as Map);
    return GuildQuestCopyResult(
      questId: row['quest_id'] as String,
      missionCount: row['mission_count'] as int? ?? 0,
      firstTaskCreated: row['first_task_created'] as bool? ?? false,
      alreadyApplied: row['already_applied'] as bool? ?? false,
    );
  }

  @override
  Future<void> recordDiscoveryOpened({
    required String publicationId,
    required String eventKey,
  }) async {
    await client.rpc(
      'record_guild_pilot_event',
      params: {
        'p_event_name': 'discovery_opened',
        'p_publication_id': publicationId,
        'p_event_key': eventKey,
      },
    );
  }

  List<String> _boundedTags(List<String> tags) {
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(20)
        .toList(growable: false);
  }

  GuildDiscoveryQuest _questFromRow(Map<String, dynamic> row) {
    return GuildDiscoveryQuest(
      id: row['id'] as String,
      title: row['title'] as String,
      summary: row['summary'] as String,
      authorDisplayName: row['author_display_name'] as String,
      tags: List<String>.from(row['tags'] as List? ?? const <String>[]),
      difficultyScore: row['difficulty_score'] as int? ?? 3,
      estimatedDurationDays: row['estimated_duration_days'] as int?,
      estimatedCostLabel: row['estimated_cost_label'] as String?,
      copyCount: row['copy_count'] as int? ?? 0,
      completionCount: row['completion_count'] as int? ?? 0,
      averageCompletionRate:
          (row['average_completion_rate'] as num?)?.toDouble() ?? 0,
      reviewScore: (row['review_score'] as num?)?.toDouble(),
      reviewCount: row['review_count'] as int? ?? 0,
      seekingCompanions: row['seeking_companions'] as bool? ?? false,
      participantCount: row['participant_count'] as int? ?? 0,
      visibility: GuildDiscoveryVisibility.values.byName(
        row['visibility'] as String,
      ),
      moderationStatus: GuildDiscoveryModerationStatus.values.byName(
        row['moderation_status'] as String,
      ),
      publishedAt: DateTime.parse(row['published_at'] as String),
    );
  }
}
