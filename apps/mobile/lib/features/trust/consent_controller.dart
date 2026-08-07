import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'consent_purpose_registry_service.dart';

enum ConsentStatus { granted, denied, withdrawn }

class ConsentDecision {
  const ConsentDecision({
    required this.status,
    required this.version,
    required this.source,
    this.changedAt,
  });
  final ConsentStatus status;
  final int version;
  final String source;
  final DateTime? changedAt;
  bool get isGranted => status == ConsentStatus.granted;
}

abstract interface class ConsentRepository {
  Future<Map<ConsentPurpose, ConsentDecision>> load();
  Future<ConsentDecision> set(
    ConsentPurpose purpose,
    bool granted, {
    required String source,
  });
}

class LocalConsentRepository implements ConsentRepository {
  static const _prefix = 'questra_consent_v1_';
  static const _storage = FlutterSecureStorage();
  @override
  Future<Map<ConsentPurpose, ConsentDecision>> load() async {
    return {
      for (final purpose in ConsentPurpose.values)
        purpose: ConsentDecision(
          status:
              await _storage.read(key: '$_prefix${purpose.storageKey}') ==
                  'true'
              ? ConsentStatus.granted
              : ConsentStatus.denied,
          version: 1,
          source: 'settings',
        ),
    };
  }

  @override
  Future<ConsentDecision> set(
    ConsentPurpose purpose,
    bool granted, {
    required String source,
  }) async {
    if (purpose == ConsentPurpose.personalDataSharing) {
      throw StateError('共有先を示す個別確認が必要です。');
    }
    await _storage.write(
      key: '$_prefix${purpose.storageKey}',
      value: '$granted',
    );
    return ConsentDecision(
      status: granted ? ConsentStatus.granted : ConsentStatus.withdrawn,
      version: 1,
      source: source,
      changedAt: DateTime.now(),
    );
  }
}

class SupabaseConsentRepository implements ConsentRepository {
  const SupabaseConsentRepository(this.client, this.fallback);
  final SupabaseClient client;
  final ConsentRepository fallback;
  @override
  Future<Map<ConsentPurpose, ConsentDecision>> load() async {
    if (client.auth.currentUser == null) {
      return fallback.load();
    }
    final rows = await client
        .from('user_consents')
        .select('purpose_code,purpose_version,status,source,created_at');
    final result = {
      for (final purpose in ConsentPurpose.values)
        purpose: const ConsentDecision(
          status: ConsentStatus.denied,
          version: 1,
          source: 'default',
        ),
    };
    for (final row in rows) {
      final purpose = ConsentPurpose.values
          .where((value) => value.storageKey == row['purpose_code'])
          .firstOrNull;
      if (purpose == null) continue;
      result[purpose] = ConsentDecision(
        status: ConsentStatus.values.byName(row['status'] as String),
        version: row['purpose_version'] as int,
        source: row['source'] as String,
        changedAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );
    }
    return result;
  }

  @override
  Future<ConsentDecision> set(
    ConsentPurpose purpose,
    bool granted, {
    required String source,
  }) async {
    if (client.auth.currentUser == null) {
      return fallback.set(purpose, granted, source: source);
    }
    if (purpose == ConsentPurpose.personalDataSharing &&
        source != 'contextual_prompt') {
      throw StateError('共有先を示す個別確認が必要です。');
    }
    final row = await client.rpc<Map<String, dynamic>>(
      'set_user_consent',
      params: {
        'p_purpose_code': purpose.storageKey,
        'p_purpose_version': 1,
        'p_granted': granted,
        'p_source': source,
      },
    );
    return ConsentDecision(
      status: ConsentStatus.values.byName(row['status'] as String),
      version: row['purpose_version'] as int,
      source: row['source'] as String,
      changedAt: DateTime.now(),
    );
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  final local = LocalConsentRepository();
  return SupabaseConfig.isConfigured
      ? SupabaseConsentRepository(Supabase.instance.client, local)
      : local;
});

final consentControllerProvider =
    AsyncNotifierProvider<
      ConsentController,
      Map<ConsentPurpose, ConsentDecision>
    >(ConsentController.new);

class ConsentController
    extends AsyncNotifier<Map<ConsentPurpose, ConsentDecision>> {
  @override
  Future<Map<ConsentPurpose, ConsentDecision>> build() =>
      ref.read(consentRepositoryProvider).load();
  Future<void> setConsent(ConsentPurpose purpose, bool granted) async {
    final current =
        state.value ?? await ref.read(consentRepositoryProvider).load();
    state = AsyncData({
      ...current,
      purpose: ConsentDecision(
        status: granted ? ConsentStatus.granted : ConsentStatus.withdrawn,
        version: 1,
        source: 'settings',
        changedAt: DateTime.now(),
      ),
    });
    try {
      final saved = await ref
          .read(consentRepositoryProvider)
          .set(purpose, granted, source: 'settings');
      state = AsyncData({...state.value!, purpose: saved});
    } catch (error, stack) {
      state = AsyncError(error, stack);
      state = AsyncData(current);
    }
  }
}
