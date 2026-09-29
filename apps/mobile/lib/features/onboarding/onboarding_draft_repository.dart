import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final onboardingDraftRepositoryProvider = Provider<OnboardingDraftRepository>(
  (ref) => SecureOnboardingDraftRepository(),
);

class OnboardingDraft {
  const OnboardingDraft({
    required this.step,
    required this.nickname,
    required this.arcName,
    required this.questWish,
    required this.updatedAt,
  });

  final int step;
  final String nickname;
  final String arcName;
  final String questWish;
  final DateTime updatedAt;
}

abstract interface class OnboardingDraftRepository {
  Future<OnboardingDraft?> load(String ownerId);
  Future<void> save(String ownerId, OnboardingDraft draft);
  Future<void> clear(String ownerId);
}

class SecureOnboardingDraftRepository implements OnboardingDraftRepository {
  SecureOnboardingDraftRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _keyPrefix = 'questra_onboarding_draft_v1_';
  static const _maxEncodedBytes = 8 * 1024;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration maxAge;

  @override
  Future<OnboardingDraft?> load(String ownerId) async {
    if (!_validOwner(ownerId)) return null;
    final key = _key(ownerId);
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null || encoded.length > _maxEncodedBytes) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return _failClosed(key);
      final row = Map<String, dynamic>.from(decoded);
      final updatedAt = DateTime.tryParse(row['updatedAt'] as String? ?? '');
      final step = row['step'];
      if (row['version'] != 1 ||
          row['ownerId'] != ownerId ||
          step is! int ||
          !const {0, 1, 4}.contains(step) ||
          updatedAt == null ||
          _clock().toUtc().difference(updatedAt.toUtc()) > maxAge) {
        return _failClosed(key);
      }
      return OnboardingDraft(
        step: step,
        nickname: row['nickname'] as String? ?? '',
        arcName: row['arcName'] as String? ?? '',
        questWish: row['questWish'] as String? ?? '',
        updatedAt: updatedAt,
      );
    } catch (_) {
      return _failClosed(key);
    }
  }

  @override
  Future<void> save(String ownerId, OnboardingDraft draft) async {
    if (!_validOwner(ownerId) || !const {0, 1, 4}.contains(draft.step)) {
      throw ArgumentError('Onboarding draft owner or step is invalid.');
    }
    final encoded = jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'step': draft.step,
      'nickname': draft.nickname,
      'arcName': draft.arcName,
      'questWish': draft.questWish,
      'updatedAt': draft.updatedAt.toUtc().toIso8601String(),
    });
    if (encoded.length > _maxEncodedBytes) {
      throw StateError('Onboarding draft is too large.');
    }
    await _storage.write(key: _key(ownerId), value: encoded);
  }

  @override
  Future<void> clear(String ownerId) async {
    if (!_validOwner(ownerId)) return;
    await _storage.delete(key: _key(ownerId));
  }

  bool _validOwner(String ownerId) =>
      ownerId.isNotEmpty && ownerId.length <= 128;

  String _key(String ownerId) =>
      '$_keyPrefix${base64Url.encode(utf8.encode(ownerId))}';

  Future<OnboardingDraft?> _failClosed(String key) async {
    await _storage.delete(key: key);
    return null;
  }
}

class InMemoryOnboardingDraftRepository implements OnboardingDraftRepository {
  InMemoryOnboardingDraftRepository({
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration maxAge;
  final Map<String, OnboardingDraft> _drafts = {};

  @override
  Future<OnboardingDraft?> load(String ownerId) async {
    final draft = _drafts[ownerId];
    if (draft == null) return null;
    if (_clock().toUtc().difference(draft.updatedAt.toUtc()) > maxAge) {
      _drafts.remove(ownerId);
      return null;
    }
    return draft;
  }

  @override
  Future<void> save(String ownerId, OnboardingDraft draft) async {
    if (ownerId.isEmpty || !const {0, 1, 4}.contains(draft.step)) {
      throw ArgumentError('Onboarding draft owner or step is invalid.');
    }
    _drafts[ownerId] = draft;
  }

  @override
  Future<void> clear(String ownerId) async => _drafts.remove(ownerId);
}
