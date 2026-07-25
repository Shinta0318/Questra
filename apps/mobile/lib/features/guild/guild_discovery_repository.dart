import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'guild_discovery_model.dart';

const _discoveryColumns =
    'id,title,summary,author_display_name,tags,difficulty_score,'
    'estimated_duration_days,estimated_cost_label,copy_count,'
    'completion_count,average_completion_rate,review_score,review_count,'
    'seeking_companions,participant_count,visibility,moderation_status,'
    'published_at';

abstract interface class GuildDiscoveryRepository {
  Future<List<GuildDiscoveryQuest>> findApprovedPublic({int limit = 20});

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
}

class SupabaseGuildDiscoveryRepository implements GuildDiscoveryRepository {
  const SupabaseGuildDiscoveryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<GuildDiscoveryQuest>> findApprovedPublic({int limit = 20}) async {
    if (limit <= 0) return const <GuildDiscoveryQuest>[];
    final safeLimit = limit.clamp(1, 50);
    final rows = await client
        .from('guild_quest_publications')
        .select(_discoveryColumns)
        .eq('visibility', 'public')
        .eq('moderation_status', 'approved')
        .order('published_at', ascending: false)
        .limit(safeLimit);

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
