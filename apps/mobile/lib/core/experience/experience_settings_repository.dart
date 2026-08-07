import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'experience_settings.dart';

final experienceSettingsRepositoryProvider =
    Provider<ExperienceSettingsRepository>((ref) {
  return PersistedExperienceSettingsRepository();
});

abstract interface class ExperienceSettingsRepository {
  Future<ExperienceSettings?> load({String? userId});

  Future<void> save(ExperienceSettings settings, {String? userId});
}

class PersistedExperienceSettingsRepository
    implements ExperienceSettingsRepository {
  PersistedExperienceSettingsRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _localKey = 'questra_experience_settings_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ExperienceSettings?> load({String? userId}) async {
    final local = await _loadLocal();
    if (!SupabaseConfig.isConfigured || userId == null) return local;

    try {
      final row = await Supabase.instance.client
          .from('user_experience_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return local;
      final remote = ExperienceSettings.fromJson(row);
      await _saveLocal(remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<void> save(ExperienceSettings settings, {String? userId}) async {
    await _saveLocal(settings);
    if (!SupabaseConfig.isConfigured || userId == null) return;

    try {
      await Supabase.instance.client.from('user_experience_settings').upsert({
        'user_id': userId,
        ...settings.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // The local preference remains authoritative until the next sync.
    }
  }

  Future<ExperienceSettings?> _loadLocal() async {
    try {
      final encoded = await _storage.read(key: _localKey);
      if (encoded == null) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      return ExperienceSettings.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocal(ExperienceSettings settings) async {
    try {
      await _storage.write(
          key: _localKey, value: jsonEncode(settings.toJson()));
    } catch (_) {
      // Unsupported or temporarily unavailable storage must not break the UI.
    }
  }
}

class InMemoryExperienceSettingsRepository
    implements ExperienceSettingsRepository {
  ExperienceSettings? value;

  @override
  Future<ExperienceSettings?> load({String? userId}) async => value;

  @override
  Future<void> save(ExperienceSettings settings, {String? userId}) async {
    value = settings;
  }
}
