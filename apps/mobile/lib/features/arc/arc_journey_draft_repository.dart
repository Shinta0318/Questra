import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'arc_chat_service.dart';

class ArcJourneyDraft {
  const ArcJourneyDraft({required this.messages, required this.updatedAt});

  final List<ArcChatMessage> messages;
  final DateTime updatedAt;
}

abstract interface class ArcJourneyDraftRepository {
  Future<ArcJourneyDraft?> load(String ownerId);
  Future<void> save(String ownerId, ArcJourneyDraft draft);
  Future<void> clear(String ownerId);
}

class SecureArcJourneyDraftRepository implements ArcJourneyDraftRepository {
  SecureArcJourneyDraftRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    this.maxAge = const Duration(days: 14),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration maxAge;

  @override
  Future<ArcJourneyDraft?> load(String ownerId) async {
    if (ownerId.isEmpty) return null;
    final key = _key(ownerId);
    try {
      final encoded = await _storage.read(key: key);
      if (encoded == null || encoded.length > 128 * 1024) return null;
      final row = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final updatedAt = DateTime.tryParse(row['updatedAt'] as String? ?? '');
      if (row['version'] != 1 ||
          row['ownerId'] != ownerId ||
          updatedAt == null ||
          _clock().toUtc().difference(updatedAt.toUtc()) > maxAge) {
        await _storage.delete(key: key);
        return null;
      }
      final messages = (row['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(
            (item) => ArcChatMessage(
              text: item['text'] as String? ?? '',
              fromArc: item['fromArc'] as bool? ?? false,
              createdAt:
                  DateTime.tryParse(item['createdAt'] as String? ?? '') ??
                  updatedAt,
            ),
          )
          .where((message) => message.text.trim().isNotEmpty)
          .take(40)
          .toList(growable: false);
      return ArcJourneyDraft(messages: messages, updatedAt: updatedAt);
    } catch (_) {
      await _storage.delete(key: key);
      return null;
    }
  }

  @override
  Future<void> save(String ownerId, ArcJourneyDraft draft) async {
    if (ownerId.isEmpty) throw ArgumentError('ownerId is required');
    final messages = draft.messages.take(40).toList(growable: false);
    final encoded = jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'updatedAt': draft.updatedAt.toUtc().toIso8601String(),
      'messages': messages
          .map(
            (message) => {
              'text': message.text,
              'fromArc': message.fromArc,
              'createdAt': message.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
    });
    if (encoded.length > 128 * 1024) {
      throw StateError('Arc draft is too large.');
    }
    await _storage.write(key: _key(ownerId), value: encoded);
  }

  @override
  Future<void> clear(String ownerId) => _storage.delete(key: _key(ownerId));

  String _key(String ownerId) =>
      'questra_arc_journey_draft_v1_${base64Url.encode(utf8.encode(ownerId))}';
}
