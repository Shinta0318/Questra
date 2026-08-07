import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

enum GuildPostModerationStatus { pending, approved, rejected, removed }

class GuildMembership {
  const GuildMembership({
    required this.guildId,
    required this.role,
    required this.status,
  });

  final String guildId;
  final String role;
  final String status;
}

class GuildPost {
  const GuildPost({
    required this.id,
    required this.guildId,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String guildId;
  final String content;
  final GuildPostModerationStatus status;
  final DateTime createdAt;
}

abstract interface class GuildRepository {
  Future<List<GuildMembership>> memberships();
  Future<void> joinPublicGuild(String guildId);
  Future<void> leaveGuild(String guildId);
  Future<List<GuildPost>> posts(String guildId, {int limit = 30});
  Future<String> createPost({required String guildId, required String content});
  Future<void> deletePost(String postId);
  Future<void> reportPost({required String postId, required String reason});
}

class SupabaseGuildRepository implements GuildRepository {
  const SupabaseGuildRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<GuildMembership>> memberships() async {
    final rows = await client
        .from('guild_members')
        .select('guild_id,role,status')
        .order('created_at');
    return rows
        .map(
          (row) => GuildMembership(
            guildId: row['guild_id'] as String,
            role: row['role'] as String,
            status: row['status'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> joinPublicGuild(String guildId) =>
      client.rpc('join_public_guild', params: {'p_guild_id': guildId});

  @override
  Future<void> leaveGuild(String guildId) =>
      client.rpc('leave_guild', params: {'p_guild_id': guildId});

  @override
  Future<List<GuildPost>> posts(String guildId, {int limit = 30}) async {
    final rows = await client
        .from('guild_posts')
        .select('id,guild_id,content,moderation_status,created_at')
        .eq('guild_id', guildId)
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 50));
    return rows
        .map(
          (row) => GuildPost(
            id: row['id'] as String,
            guildId: row['guild_id'] as String,
            content: row['content'] as String,
            status: GuildPostModerationStatus.values.byName(
              row['moderation_status'] as String,
            ),
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> createPost({
    required String guildId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.length > 1200) {
      throw ArgumentError.value(content, 'content', '投稿は1〜1200文字で入力してください。');
    }
    return await client.rpc(
          'create_guild_post',
          params: {'p_guild_id': guildId, 'p_content': trimmed},
        )
        as String;
  }

  @override
  Future<void> deletePost(String postId) =>
      client.rpc('delete_guild_post', params: {'p_post_id': postId});

  @override
  Future<void> reportPost({required String postId, required String reason}) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty || trimmed.length > 500) {
      throw ArgumentError.value(reason, 'reason', '通報理由は1〜500文字で入力してください。');
    }
    return client.rpc(
      'report_guild_post',
      params: {'p_post_id': postId, 'p_reason': trimmed},
    );
  }
}
