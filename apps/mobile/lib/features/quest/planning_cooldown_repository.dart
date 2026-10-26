import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final planningCooldownRepositoryProvider = Provider<PlanningCooldownRepository>(
  (ref) => SecurePlanningCooldownRepository(),
);

abstract interface class PlanningCooldownRepository {
  Future<DateTime?> load(String ownerId, String questId);
  Future<void> save(String ownerId, String questId, DateTime retryAt);
  Future<void> clear(String ownerId, String questId);
}

class SecurePlanningCooldownRepository implements PlanningCooldownRepository {
  SecurePlanningCooldownRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _keyPrefix = 'questra_planning_cooldown_v1_';
  static const _maxDuration = Duration(hours: 1, minutes: 5);
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;

  @override
  Future<DateTime?> load(String ownerId, String questId) async {
    if (!_validId(ownerId) || !_validId(questId)) return null;
    final key = _key(ownerId, questId);
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null) return null;
      final retryAt = DateTime.tryParse(encoded)?.toUtc();
      final remaining = retryAt?.difference(_clock().toUtc());
      if (remaining == null ||
          remaining <= Duration.zero ||
          remaining > _maxDuration) {
        await _storage.delete(key: key);
        return null;
      }
      return retryAt;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String ownerId, String questId, DateTime retryAt) async {
    if (!_validId(ownerId) || !_validId(questId)) return;
    final remaining = retryAt.difference(_clock());
    if (remaining <= Duration.zero || remaining > _maxDuration) return;
    await _storage.write(
      key: _key(ownerId, questId),
      value: retryAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear(String ownerId, String questId) async {
    if (!_validId(ownerId) || !_validId(questId)) return;
    await _storage.delete(key: _key(ownerId, questId));
  }

  String _key(String ownerId, String questId) =>
      '$_keyPrefix${base64Url.encode(utf8.encode(ownerId))}_${base64Url.encode(utf8.encode(questId))}';

  bool _validId(String value) => value.isNotEmpty && value.length <= 128;
}

class InMemoryPlanningCooldownRepository implements PlanningCooldownRepository {
  final Map<String, DateTime> _entries = {};

  @override
  Future<DateTime?> load(String ownerId, String questId) async =>
      _entries['$ownerId:$questId'];

  @override
  Future<void> save(String ownerId, String questId, DateTime retryAt) async {
    _entries['$ownerId:$questId'] = retryAt;
  }

  @override
  Future<void> clear(String ownerId, String questId) async {
    _entries.remove('$ownerId:$questId');
  }
}
