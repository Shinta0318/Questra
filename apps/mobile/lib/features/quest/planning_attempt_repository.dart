import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

abstract interface class PlanningAttemptRepository {
  Future<String> loadOrCreate(
    String? ownerId,
    String questId,
    String inputFingerprint,
  );
  Future<void> clear(
    String? ownerId,
    String questId,
    String inputFingerprint,
    String attemptKey,
  );
}

class SecurePlanningAttemptRepository implements PlanningAttemptRepository {
  SecurePlanningAttemptRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  static const _prefix = 'questra_planning_attempt_v1_';
  static const _lifetime = Duration(hours: 24);
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final String Function() _newId;

  @override
  Future<String> loadOrCreate(
    String? ownerId,
    String questId,
    String inputFingerprint,
  ) async {
    final key = _storageKey(ownerId, questId);
    if (key == null || !_validFingerprint(inputFingerprint)) return _freshId();
    try {
      final encoded = await _storage.read(key: key);
      if (encoded != null) {
        final value = jsonDecode(encoded);
        if (value is Map) {
          final attempt = value['idempotency_key'];
          final issuedAt = DateTime.tryParse(
            value['issued_at']?.toString() ?? '',
          );
          final age = issuedAt == null
              ? null
              : _clock().toUtc().difference(issuedAt.toUtc());
          if (attempt is String &&
              _validAttempt(attempt) &&
              value['input_fingerprint'] == inputFingerprint &&
              age != null &&
              age >= Duration.zero &&
              age < _lifetime) {
            return attempt;
          }
        }
      }
    } catch (_) {
      // A storage failure must not expose or reuse an unrelated attempt.
    }
    final fresh = _freshId();
    try {
      await _storage.write(
        key: key,
        value: jsonEncode({
          'idempotency_key': fresh,
          'input_fingerprint': inputFingerprint,
          'issued_at': _clock().toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // The current invocation can still complete without durable recovery.
    }
    return fresh;
  }

  @override
  Future<void> clear(
    String? ownerId,
    String questId,
    String inputFingerprint,
    String attemptKey,
  ) async {
    final key = _storageKey(ownerId, questId);
    if (key == null) return;
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null) return;
      final value = jsonDecode(encoded);
      if (value is Map &&
          value['input_fingerprint'] == inputFingerprint &&
          value['idempotency_key'] == attemptKey) {
        await _storage.delete(key: key);
      }
    } catch (_) {
      // An expired leftover is ignored on the next load.
    }
  }

  String _freshId() => 'flutter-${_newId()}';

  bool _validAttempt(String value) =>
      RegExp(r'^flutter-[0-9a-fA-F-]{36}$').hasMatch(value);

  bool _validFingerprint(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  String? _storageKey(String? ownerId, String questId) {
    if (ownerId == null ||
        ownerId.isEmpty ||
        ownerId.length > 128 ||
        questId.isEmpty ||
        questId.length > 128) {
      return null;
    }
    final owner = base64Url.encode(utf8.encode(ownerId));
    final quest = base64Url.encode(utf8.encode(questId));
    return '$_prefix${owner}_$quest';
  }
}
