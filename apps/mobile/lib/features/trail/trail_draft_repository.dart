import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final trailDraftRepositoryProvider = Provider<TrailDraftRepository>(
  (ref) => SecureTrailDraftRepository(),
);

class TrailComposerDraft {
  const TrailComposerDraft({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.showDetails,
    required this.updatedAt,
    this.questId,
    this.missionId,
  });

  final String id;
  final String? questId;
  final String? missionId;
  final String title;
  final String summary;
  final String content;
  final bool showDetails;
  final DateTime updatedAt;

  bool get isEmpty =>
      title.trim().isEmpty && summary.trim().isEmpty && content.trim().isEmpty;
}

abstract interface class TrailDraftRepository {
  Future<TrailComposerDraft?> load(String ownerId);
  Future<void> save(String ownerId, TrailComposerDraft draft);
  Future<void> clear(String ownerId);
}

class SecureTrailDraftRepository implements TrailDraftRepository {
  SecureTrailDraftRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _maxEncodedBytes = 16 * 1024;
  static const _keyPrefix = 'questra_trail_draft_v1_';
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration maxAge;

  @override
  Future<TrailComposerDraft?> load(String ownerId) async {
    if (!_validOwner(ownerId)) return null;
    final key = _key(ownerId);
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null || encoded.length > _maxEncodedBytes) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return _failClosed(key);
      final row = Map<String, dynamic>.from(decoded);
      final updatedAt = DateTime.tryParse(row['updatedAt'] as String? ?? '');
      if (row['version'] != 1 ||
          row['ownerId'] != ownerId ||
          updatedAt == null ||
          _clock().toUtc().difference(updatedAt.toUtc()) > maxAge) {
        return _failClosed(key);
      }
      final draft = TrailComposerDraft(
        id: row['id'] as String? ?? '',
        questId: _optionalId(row['questId']),
        missionId: _optionalId(row['missionId']),
        title: row['title'] as String? ?? '',
        summary: row['summary'] as String? ?? '',
        content: row['content'] as String? ?? '',
        showDetails: row['showDetails'] as bool? ?? false,
        updatedAt: updatedAt,
      );
      if (draft.id.isEmpty || draft.isEmpty) return _failClosed(key);
      return draft;
    } catch (_) {
      return _failClosed(key);
    }
  }

  @override
  Future<void> save(String ownerId, TrailComposerDraft draft) async {
    if (!_validOwner(ownerId) || draft.id.isEmpty) {
      throw ArgumentError('Trail draft owner or id is invalid.');
    }
    if (draft.isEmpty) return clear(ownerId);
    final encoded = jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'id': draft.id,
      'questId': draft.questId,
      'missionId': draft.missionId,
      'title': draft.title,
      'summary': draft.summary,
      'content': draft.content,
      'showDetails': draft.showDetails,
      'updatedAt': draft.updatedAt.toUtc().toIso8601String(),
    });
    if (encoded.length > _maxEncodedBytes) {
      throw StateError('Trail draft is too large.');
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

  Future<TrailComposerDraft?> _failClosed(String key) async {
    await _storage.delete(key: key);
    return null;
  }

  static String? _optionalId(Object? value) {
    final id = value is String ? value.trim() : '';
    return id.isEmpty ? null : id;
  }
}

class InMemoryTrailDraftRepository implements TrailDraftRepository {
  InMemoryTrailDraftRepository({
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 7),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration maxAge;
  final Map<String, TrailComposerDraft> _drafts = {};

  @override
  Future<TrailComposerDraft?> load(String ownerId) async {
    final draft = _drafts[ownerId];
    if (draft == null) return null;
    if (_clock().toUtc().difference(draft.updatedAt.toUtc()) > maxAge) {
      _drafts.remove(ownerId);
      return null;
    }
    return draft;
  }

  @override
  Future<void> save(String ownerId, TrailComposerDraft draft) async {
    if (ownerId.isEmpty || draft.id.isEmpty) {
      throw ArgumentError('Trail draft owner or id is invalid.');
    }
    if (draft.isEmpty) {
      _drafts.remove(ownerId);
    } else {
      _drafts[ownerId] = draft;
    }
  }

  @override
  Future<void> clear(String ownerId) async => _drafts.remove(ownerId);
}
