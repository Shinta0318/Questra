import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../mission/mission_model.dart';
import 'mission_support_model.dart';

abstract interface class MissionResearchService {
  Future<MissionResearchResult> research(
    Mission mission, {
    bool forceRefresh = false,
  });
}

class LocalMissionResearchService implements MissionResearchService {
  const LocalMissionResearchService();

  @override
  Future<MissionResearchResult> research(
    Mission mission, {
    bool forceRefresh = false,
  }) {
    throw StateError('最新情報を調べるにはオンライン接続が必要です。');
  }
}

class SupabaseMissionResearchService implements MissionResearchService {
  const SupabaseMissionResearchService(this.client);

  final SupabaseClient client;

  @override
  Future<MissionResearchResult> research(
    Mission mission, {
    bool forceRefresh = false,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return const LocalMissionResearchService().research(mission);
    }
    final response = await client.functions.invoke(
      'research-mission-resources',
      body: {
        'force_refresh': forceRefresh,
        'mission': {
          'id': mission.id,
          'title': mission.title,
          'description': mission.description,
          'quest_id': mission.questId,
          'quest_title': mission.questTitle,
        },
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return MissionResearchResult(
      summary: data['summary'] as String? ?? '',
      checkpoints:
          (data['checkpoints'] as List?)?.whereType<String>().toList() ??
              const [],
      cautions:
          (data['cautions'] as List?)?.whereType<String>().toList() ?? const [],
      references: (data['sources'] as List?)
              ?.whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .map(_referenceFromData)
              .whereType<MissionReference>()
              .take(8)
              .toList(growable: false) ??
          const [],
      sourceType: data['source_type'] as String? ?? 'grounded_search',
    );
  }

  MissionReference? _referenceFromData(Map<String, dynamic> data) {
    final uri = Uri.tryParse(data['url'] as String? ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return MissionReference(
      title: data['title'] as String? ?? uri.host,
      publisher: data['publisher'] as String? ?? uri.host,
      url: uri,
      retrievedAt: DateTime.tryParse(data['retrieved_at'] as String? ?? '') ??
          DateTime.now(),
      verified: data['verified'] as bool? ?? false,
    );
  }
}
