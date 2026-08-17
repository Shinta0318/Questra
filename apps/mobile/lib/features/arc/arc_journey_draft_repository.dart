import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quest/quest_clarification_service.dart';
import '../quest/quest_model.dart';
import 'arc_chat_service.dart';
import 'arc_quest_clarification_session.dart';

final arcJourneyDraftRepositoryProvider = Provider<ArcJourneyDraftRepository>(
  (ref) => SecureArcJourneyDraftRepository(),
);

class ArcJourneyDraft {
  const ArcJourneyDraft({
    required this.messages,
    required this.updatedAt,
    this.clarificationSession,
    this.questSuggestion,
  });

  final List<ArcChatMessage> messages;
  final DateTime updatedAt;
  final ArcQuestClarificationSession? clarificationSession;
  final ArcQuestSuggestion? questSuggestion;
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
      final version = row['version'];
      if ((version != 1 && version != 2) ||
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
      final suggestion = version == 2
          ? _suggestionFromJson(row['questSuggestion'])
          : null;
      final session = version == 2
          ? _sessionFromJson(row['clarificationSession'])
          : null;
      return ArcJourneyDraft(
        messages: messages,
        updatedAt: updatedAt,
        clarificationSession: session,
        questSuggestion: session == null ? suggestion : null,
      );
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
      'version': 2,
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
      'clarificationSession': _sessionToJson(draft.clarificationSession),
      'questSuggestion': _suggestionToJson(draft.questSuggestion),
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

  static Map<String, Object?>? _sessionToJson(
    ArcQuestClarificationSession? session,
  ) {
    if (session == null) return null;
    return {
      'suggestion': _suggestionToJson(session.suggestion),
      'questions': session.questions
          .map(
            (question) => {
              'type': question.type.storageKey,
              'label': question.label,
              'hint': question.hint,
            },
          )
          .toList(growable: false),
      'answers': {
        for (final entry in session.answers.entries)
          entry.key.storageKey: entry.value,
      },
    };
  }

  static ArcQuestClarificationSession? _sessionFromJson(Object? value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final suggestion = _suggestionFromJson(row['suggestion']);
    final questions = (row['questions'] as List? ?? const [])
        .whereType<Map>()
        .map(QuestClarificationQuestion.fromJson)
        .whereType<QuestClarificationQuestion>()
        .take(5)
        .toList(growable: false);
    if (suggestion == null || questions.isEmpty) return null;
    final answers = <QuestClarificationType, String>{};
    final rawAnswers = row['answers'];
    if (rawAnswers is Map) {
      for (final entry in rawAnswers.entries) {
        final type = questClarificationTypeFromStorage(entry.key);
        final answer = entry.value is String
            ? (entry.value as String).trim()
            : '';
        if (type != null &&
            answer.isNotEmpty &&
            questions.any((question) => question.type == type)) {
          answers[type] = answer;
        }
      }
    }
    return ArcQuestClarificationSession(
      suggestion: suggestion,
      questions: questions,
      answers: answers,
    );
  }

  static Map<String, Object?>? _suggestionToJson(
    ArcQuestSuggestion? suggestion,
  ) {
    if (suggestion == null) return null;
    return {
      'title': suggestion.title,
      'description': suggestion.description,
      'category': suggestion.category,
      'difficulty': suggestion.difficulty.storageKey,
      'sourceInput': suggestion.sourceInput,
      'motivation': suggestion.motivation,
      'successCondition': suggestion.successCondition,
      'realityFrame': suggestion.realityFrame,
      'reframedOutcome': suggestion.reframedOutcome,
    };
  }

  static ArcQuestSuggestion? _suggestionFromJson(Object? value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final title = (row['title'] as String?)?.trim() ?? '';
    final sourceInput = (row['sourceInput'] as String?)?.trim() ?? '';
    if (title.isEmpty || sourceInput.isEmpty) return null;
    return ArcQuestSuggestion(
      title: title,
      description: (row['description'] as String?)?.trim() ?? sourceInput,
      category: (row['category'] as String?)?.trim() ?? '冒険',
      difficulty: QuestDifficulty.values.firstWhere(
        (item) => item.storageKey == row['difficulty'],
        orElse: () => QuestDifficulty.normal,
      ),
      sourceInput: sourceInput,
      motivation: (row['motivation'] as String?)?.trim() ?? '',
      successCondition: (row['successCondition'] as String?)?.trim() ?? '',
      realityFrame: (row['realityFrame'] as String?)?.trim() ?? 'uncertain',
      reframedOutcome: (row['reframedOutcome'] as String?)?.trim(),
    );
  }
}
