import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

enum TrailShareAvailability { available, notAvailable, rateLimited }

enum TrailShareReportReason { spam, unsafe, personalInfo, harassment, other }

class TrailShareSnapshot {
  const TrailShareSnapshot({
    required this.availability,
    this.expiresAt,
    this.title,
    this.summary,
    this.content,
  });

  final TrailShareAvailability availability;
  final DateTime? expiresAt;
  final String? title;
  final String? summary;
  final String? content;
}

class TrailShareLink {
  const TrailShareLink({
    required this.id,
    required this.token,
    required this.expiresAt,
  });

  final String id;
  final String token;
  final DateTime expiresAt;
}

abstract interface class TrailShareRepository {
  Future<TrailShareLink> create({
    required String trailId,
    required bool includeTitle,
    required bool includeSummary,
    required bool includeContent,
    required DateTime expiresAt,
  });

  Future<void> revoke(String linkId);

  Future<TrailShareSnapshot> resolve(String token);

  Future<void> report({
    required String token,
    required TrailShareReportReason reason,
  });
}

class SupabaseTrailShareRepository implements TrailShareRepository {
  const SupabaseTrailShareRepository(this.client);

  final SupabaseClient client;

  @override
  Future<TrailShareLink> create({
    required String trailId,
    required bool includeTitle,
    required bool includeSummary,
    required bool includeContent,
    required DateTime expiresAt,
  }) async {
    final result = await client.rpc(
      'create_trail_share_link',
      params: {
        'p_trail_id': trailId,
        'p_include_title': includeTitle,
        'p_include_summary': includeSummary,
        'p_include_content': includeContent,
        'p_expires_at': expiresAt.toUtc().toIso8601String(),
      },
    );
    final rows = result as List;
    if (rows.isEmpty) throw StateError('Trail share link was not created.');
    final row = Map<String, dynamic>.from(rows.first as Map);
    return TrailShareLink(
      id: row['id'] as String,
      token: row['share_token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  @override
  Future<void> revoke(String linkId) async {
    await client.rpc('revoke_trail_share_link', params: {'p_link_id': linkId});
  }

  @override
  Future<TrailShareSnapshot> resolve(String token) async {
    final result = await client.rpc(
      'resolve_trail_share_link_guarded',
      params: {'p_token': token},
    );
    final row = Map<String, dynamic>.from(result as Map);
    final status = row['status'] as String?;
    if (status == 'rate_limited') {
      return const TrailShareSnapshot(
        availability: TrailShareAvailability.rateLimited,
      );
    }
    if (status != 'available') {
      return const TrailShareSnapshot(
        availability: TrailShareAvailability.notAvailable,
      );
    }
    final fields = Map<String, dynamic>.from(row['fields'] as Map? ?? const {});
    return TrailShareSnapshot(
      availability: TrailShareAvailability.available,
      expiresAt: DateTime.tryParse(
        row['expiresAt'] as String? ?? '',
      )?.toLocal(),
      title: fields['title'] as String?,
      summary: fields['summary'] as String?,
      content: fields['content'] as String?,
    );
  }

  @override
  Future<void> report({
    required String token,
    required TrailShareReportReason reason,
  }) async {
    await client.rpc(
      'report_trail_share_link_guarded',
      params: {'p_token': token, 'p_reason_code': reason.storageKey},
    );
  }
}

extension TrailShareReportReasonLabel on TrailShareReportReason {
  String get storageKey => switch (this) {
    TrailShareReportReason.spam => 'spam',
    TrailShareReportReason.unsafe => 'unsafe',
    TrailShareReportReason.personalInfo => 'personal_info',
    TrailShareReportReason.harassment => 'harassment',
    TrailShareReportReason.other => 'other',
  };

  String get label => switch (this) {
    TrailShareReportReason.spam => '迷惑な共有',
    TrailShareReportReason.unsafe => '危険な内容',
    TrailShareReportReason.personalInfo => '個人情報が含まれる',
    TrailShareReportReason.harassment => '嫌がらせ',
    TrailShareReportReason.other => 'その他',
  };
}
