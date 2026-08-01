import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'mission_source_reference.dart';

final missionSourceReferenceRepositoryProvider =
    Provider<MissionSourceReferenceRepository>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseMissionSourceReferenceRepository(
          Supabase.instance.client,
        );
      }
      return InMemoryMissionSourceReferenceRepository();
    });

final missionSourceReferencesProvider =
    FutureProvider.family<List<MissionSourceReference>, String>(
      (ref, missionId) => ref
          .watch(missionSourceReferenceRepositoryProvider)
          .findByMission(missionId),
    );

abstract interface class MissionSourceReferenceRepository {
  Future<List<MissionSourceReference>> findByMission(String missionId);
  Future<void> save(String missionId, MissionSourceReference reference);
}

class InMemoryMissionSourceReferenceRepository
    implements MissionSourceReferenceRepository {
  final Map<String, List<MissionSourceReference>> _values = {};

  @override
  Future<List<MissionSourceReference>> findByMission(String missionId) async =>
      List.unmodifiable(_values[missionId] ?? const []);

  @override
  Future<void> save(String missionId, MissionSourceReference reference) async {
    _validate(reference);
    final list = _values.putIfAbsent(missionId, () => []);
    list.removeWhere((item) => item.url == reference.url);
    list.insert(0, reference);
  }
}

class SupabaseMissionSourceReferenceRepository
    implements MissionSourceReferenceRepository {
  const SupabaseMissionSourceReferenceRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<MissionSourceReference>> findByMission(String missionId) async {
    final rows = await client
        .from('mission_source_references')
        .select(
          'title,source_url,publisher,checked_at,recheck_after,is_official',
        )
        .eq('mission_id', missionId)
        .order('checked_at', ascending: false)
        .limit(20);
    return rows
        .map(
          (row) => MissionSourceReference(
            title: row['title'] as String,
            url: Uri.parse(row['source_url'] as String),
            publisher: row['publisher'] as String,
            checkedAt: DateTime.parse(row['checked_at'] as String),
            recheckAfter: DateTime.tryParse(
              row['recheck_after'] as String? ?? '',
            ),
            isOfficial: row['is_official'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(String missionId, MissionSourceReference reference) async {
    _validate(reference);
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('ログインが必要です。');
    await client.from('mission_source_references').upsert({
      'owner_id': ownerId,
      'mission_id': missionId,
      'title': reference.title,
      'source_url': reference.url.toString(),
      'publisher': reference.publisher,
      'checked_at': reference.checkedAt.toUtc().toIso8601String(),
      'recheck_after': reference.recheckAfter?.toUtc().toIso8601String(),
      'is_official': reference.isOfficial,
    }, onConflict: 'owner_id,mission_id,source_url');
  }
}

void _validate(MissionSourceReference reference) {
  if (reference.url.scheme != 'https') {
    throw const FormatException('HTTPSの情報源だけを保存できます。');
  }
  if (reference.recheckAfter != null &&
      !reference.recheckAfter!.isAfter(reference.checkedAt)) {
    throw const FormatException('再確認日は確認日より後にしてください。');
  }
}
