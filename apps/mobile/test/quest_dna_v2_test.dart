import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_dna.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('Quest DNA v2 restores all bounded Master Spec attributes', () {
    final dna = QuestDna.fromJson({
      'attributes': {for (final key in QuestDna.keys) key: '$key value'},
      'version': 'quest-dna-v2',
      'evaluated_at': '2026-07-31T00:00:00Z',
      'provenance': 'gemini_structured_output',
    });

    expect(dna, isNotNull);
    expect(dna!.attributes.length, QuestDna.keys.length);
    expect(dna.valueFor('enterprise_relevance'), 'enterprise_relevance value');
    expect(dna.version, 'quest-dna-v2');
  });

  test('fallback never omits a Quest DNA v2 attribute', () {
    final dna = QuestDna.fallback(
      Quest(
        title: '富士山に登る',
        description: '来年の夏に達成したい',
        difficulty: QuestDifficulty.hard,
        status: QuestStatus.draft,
        visibility: QuestVisibility.private,
      ),
    );

    expect(dna.attributes.keys.toSet(), QuestDna.keys.toSet());
    expect(dna.provenance, 'local_fallback');
  });
}
