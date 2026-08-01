import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'mission_support_profile.dart';

abstract interface class MissionSupportProfileRepository {
  Future<MissionSupportProfile?> find(String missionId);
  Future<void> save(String missionId, MissionSupportProfile profile);
}

class InMemoryMissionSupportProfileRepository
    implements MissionSupportProfileRepository {
  final Map<String, MissionSupportProfile> values = {};
  @override
  Future<MissionSupportProfile?> find(String missionId) async =>
      values[missionId];
  @override
  Future<void> save(String missionId, MissionSupportProfile profile) async {
    values[missionId] = profile;
  }
}

class SupabaseMissionSupportProfileRepository
    implements MissionSupportProfileRepository {
  const SupabaseMissionSupportProfileRepository(this.client);
  final SupabaseClient client;
  @override
  Future<MissionSupportProfile?> find(String missionId) async {
    final row = await client
        .from('mission_support_profiles')
        .select()
        .eq('mission_id', missionId)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    MissionSupportType parseType(String value) =>
        MissionSupportType.values
            .where((item) => item.name == value)
            .firstOrNull ??
        MissionSupportType.other;
    return MissionSupportProfile(
      supportTypes: ((row['support_types'] as List?) ?? const [])
          .cast<String>()
          .map(parseType)
          .toSet(),
      externalServiceNeeded: row['external_service_needed'] as bool,
      providerCategories: ((row['provider_categories'] as List?) ?? const [])
          .cast<String>(),
      commercialIntent: MissionCommercialIntent.values.firstWhere(
        (value) => value.storageKey == row['commercial_intent'],
      ),
      actionWindow: MissionActionWindow.values.firstWhere(
        (value) => value.storageKey == row['estimated_action_window'],
      ),
      sponsorable: row['sponsorable'] as bool,
      sensitivity: MissionSupportSensitivity.values.byName(
        row['sensitivity_level'] as String,
      ),
      userConsentRequired: row['user_consent_required'] as bool,
      businessRecommendationsEnabled:
          row['business_recommendations_enabled'] as bool,
      confidence: (row['confidence'] as num).toDouble(),
      source: row['source'] as String,
    );
  }

  @override
  Future<void> save(String missionId, MissionSupportProfile profile) async {
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('ログインが必要です。');
    final latest = await client
        .from('mission_support_profiles')
        .select('version')
        .eq('mission_id', missionId)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    final version = ((latest?['version'] as int?) ?? 0) + 1;
    await client.from('mission_support_profiles').insert({
      'mission_id': missionId,
      'owner_id': ownerId,
      'version': version,
      'support_types': profile.supportTypes.map((value) => value.name).toList(),
      'external_service_needed': profile.externalServiceNeeded,
      'provider_categories': profile.providerCategories,
      'commercial_intent': profile.commercialIntent.storageKey,
      'estimated_action_window': profile.actionWindow.storageKey,
      'sponsorable': profile.sponsorable,
      'sensitivity_level': profile.sensitivity.name,
      'user_consent_required': profile.userConsentRequired,
      'business_recommendations_enabled':
          profile.businessRecommendationsEnabled,
      'confidence': profile.confidence,
      'source': profile.source,
    });
  }
}

final missionSupportProfileRepositoryProvider =
    Provider<MissionSupportProfileRepository>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseMissionSupportProfileRepository(
          Supabase.instance.client,
        );
      }
      return InMemoryMissionSupportProfileRepository();
    });

final missionSupportProfileProvider =
    FutureProvider.family<MissionSupportProfile?, String>(
      (ref, missionId) =>
          ref.watch(missionSupportProfileRepositoryProvider).find(missionId),
    );
