import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_journey_draft_repository.dart';
import 'package:questra/features/arc/arc_quest_clarification_session.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'restores conversation, clarification answers and Quest proposal',
    () async {
      const storage = FlutterSecureStorage();
      final now = DateTime.utc(2026, 8, 9, 12);
      final repository = SecureArcJourneyDraftRepository(
        storage: storage,
        clock: () => now,
      );
      const suggestion = ArcQuestSuggestion(
        title: 'シンガポールへ行く',
        description: 'シンガポール旅行を実現する',
        category: '旅行',
        difficulty: QuestDifficulty.normal,
        sourceInput: 'シンガポールに行きたい',
      );
      const deadline = QuestClarificationQuestion(
        type: QuestClarificationType.deadline,
        label: 'いつ頃までに叶えたい？',
        hint: '例: 2027年3月',
      );
      final session = ArcQuestClarificationSession(
        suggestion: suggestion,
        questions: const [deadline],
        answers: const {QuestClarificationType.deadline: '2027年3月'},
      );

      await repository.save(
        'owner-a',
        ArcJourneyDraft(
          messages: [
            ArcChatMessage(text: '行きたい', fromArc: false, createdAt: now),
          ],
          updatedAt: now,
          clarificationSession: session,
        ),
      );

      final restored = await repository.load('owner-a');
      expect(restored, isNotNull);
      expect(restored!.messages.single.text, '行きたい');
      expect(restored.clarificationSession?.suggestion.title, 'シンガポールへ行く');
      expect(
        restored.clarificationSession?.answers[QuestClarificationType.deadline],
        '2027年3月',
      );
    },
  );

  test('never exposes a draft to another owner and supports discard', () async {
    const storage = FlutterSecureStorage();
    final now = DateTime.utc(2026, 8, 9, 12);
    final repository = SecureArcJourneyDraftRepository(
      storage: storage,
      clock: () => now,
    );
    await repository.save(
      'owner-a',
      ArcJourneyDraft(
        messages: [
          ArcChatMessage(text: '秘密の相談', fromArc: false, createdAt: now),
        ],
        updatedAt: now,
      ),
    );

    expect(await repository.load('owner-b'), isNull);
    expect(await repository.load('owner-a'), isNotNull);
    await repository.clear('owner-a');
    expect(await repository.load('owner-a'), isNull);
  });

  test('expires stale drafts before they reach Arc screen', () async {
    const storage = FlutterSecureStorage();
    final savedAt = DateTime.utc(2026, 7, 1);
    final repository = SecureArcJourneyDraftRepository(
      storage: storage,
      clock: () => DateTime.utc(2026, 8, 9),
    );
    await repository.save(
      'owner-a',
      ArcJourneyDraft(
        messages: [
          ArcChatMessage(text: '古い相談', fromArc: false, createdAt: savedAt),
        ],
        updatedAt: savedAt,
      ),
    );

    expect(await repository.load('owner-a'), isNull);
  });
}
