import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/arc_quest_creation_service.dart';

void main() {
  group('LocalArcQuestCreationService', () {
    const service = LocalArcQuestCreationService();

    test('natural language input creates editable Quest candidates', () async {
      final draft = await service.generate(input: '自分のサービスを世に出して誰かの挑戦を支えたい');

      expect(draft.input, '自分のサービスを世に出して誰かの挑戦を支えたい');
      expect(draft.candidates.length, inInclusiveRange(3, 7));
      expect(
        draft.candidates,
        everyElement(
          isA<ArcQuestCandidate>().having(
            (candidate) => candidate.title,
            'title',
            isNotEmpty,
          ),
        ),
      );
    });

    test(
      'regeneration changes the proposed route without losing input',
      () async {
        final first = await service.generate(input: '富士山に登りたい');
        final second = await service.generate(input: '富士山に登りたい', variation: 1);

        expect(second.input, first.input);
        expect(
          second.candidates.first.title,
          isNot(first.candidates.first.title),
        );
      },
    );
  });

  group('ArcQuestDraft', () {
    test('supports edit, add, remove, reorder, and seven item cap', () {
      final first = ArcQuestCandidate(title: 'A');
      final second = ArcQuestCandidate(title: 'B');
      var draft = ArcQuestDraft(
        input: '挑戦したい',
        candidates: [
          first,
          second,
          ArcQuestCandidate(title: 'C'),
        ],
      );

      draft = draft.update(first.id, '編集後');
      draft = draft.move(0, 2);
      expect(draft.candidates.last.title, '編集後');

      draft = draft.remove(second.id);
      expect(
        draft.candidates.map((candidate) => candidate.title),
        isNot(contains('B')),
      );

      while (draft.candidates.length < 7) {
        draft = draft.add();
      }
      final capped = draft.add('8件目');
      expect(capped.candidates, hasLength(7));
    });

    test('only non-empty candidates are eligible for confirmation', () {
      final draft = ArcQuestDraft(
        input: '挑戦したい',
        candidates: [
          ArcQuestCandidate(title: '残すQuest'),
          ArcQuestCandidate(title: '  '),
        ],
      );

      expect(draft.validCandidates, hasLength(1));
      expect(draft.validCandidates.single.title, '残すQuest');
    });
  });
}
