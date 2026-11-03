import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'planning_preferences.dart';

final planningPreferencesRepositoryProvider =
    Provider<PlanningPreferencesRepository>(
      (ref) => PersistedPlanningPreferencesRepository(),
    );

abstract interface class PlanningPreferencesRepository {
  Future<PlanningPreferences?> load({String? userId});
  Future<void> save(PlanningPreferences value, {String? userId});
}

class PersistedPlanningPreferencesRepository
    implements PlanningPreferencesRepository {
  PersistedPlanningPreferencesRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _localKeyPrefix = 'questra_planning_preferences_v2';
  final FlutterSecureStorage _storage;

  String _localKey(String? userId) =>
      '$_localKeyPrefix:${userId ?? 'anonymous'}';

  @override
  Future<PlanningPreferences?> load({String? userId}) async {
    final local = await _loadLocal(userId);
    if (!SupabaseConfig.isConfigured || userId == null) return local;
    try {
      final row = await Supabase.instance.client
          .from('weekly_availability')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return local;
      final remote = PlanningPreferences.fromJson(row);
      await _saveLocal(remote, userId);
      return remote;
    } catch (_) {
      return local;
    }
  }

  @override
  Future<void> save(PlanningPreferences value, {String? userId}) async {
    await _saveLocal(value, userId);
    if (!SupabaseConfig.isConfigured || userId == null) return;
    try {
      await Supabase.instance.client
          .from('weekly_availability')
          .upsert(value.toRemoteJson(userId));
    } catch (_) {
      // Local settings remain available until the next successful sync.
    }
  }

  Future<PlanningPreferences?> _loadLocal(String? userId) async {
    try {
      final encoded = await _storage.read(key: _localKey(userId));
      if (encoded == null) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return PlanningPreferences.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocal(PlanningPreferences value, String? userId) async {
    try {
      await _storage.write(
        key: _localKey(userId),
        value: jsonEncode(value.toJson()),
      );
    } catch (_) {
      // Unsupported secure storage must not block planning.
    }
  }
}

class InMemoryPlanningPreferencesRepository
    implements PlanningPreferencesRepository {
  PlanningPreferences? value;

  @override
  Future<PlanningPreferences?> load({String? userId}) async => value;

  @override
  Future<void> save(PlanningPreferences value, {String? userId}) async {
    this.value = value;
  }
}
