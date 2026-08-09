import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_dna_snapshot.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  const resolver = QuestDnaSnapshotResolver();

  Quest quest({
    required String title,
    String category = '冒険',
    QuestDifficulty difficulty = QuestDifficulty.normal,
    QuestVisibility visibility = QuestVisibility.private,
    DateTime? targetDate,
  }) {
    return Quest(
      title: title,
      description: 'Questの説明',
      difficulty: difficulty,
      status: QuestStatus.active,
      visibility: visibility,
      category: category,
      targetDate: targetDate,
    );
  }

  test('snapshot separates user input and inferred attributes', () {
    final snapshot = resolver.resolve(
      quest(
        title: '英語を話せるようになる',
        category: '学習',
        visibility: QuestVisibility.guild,
      ),
    );

    final category = snapshot.attributes.firstWhere(
      (attribute) => attribute.key == 'category',
    );
    final theme = snapshot.attributes.firstWhere(
      (attribute) => attribute.key == 'theme',
    );
    final social = snapshot.attributes.firstWhere(
      (attribute) => attribute.key == 'social_type',
    );

    expect(category.value, '学習');
    expect(category.source, QuestDnaSource.userInput);
    expect(theme.value, '学びの航海');
    expect(theme.source, QuestDnaSource.inferred);
    expect(social.value, 'Guild');
  });

  test('snapshot flags higher risk for physical or legendary quests', () {
    final mountain = resolver.resolve(quest(title: '富士山に登る', category: '挑戦'));
    final legendary = resolver.resolve(
      quest(
        title: '会社を立ち上げる',
        category: '仕事',
        difficulty: QuestDifficulty.legendary,
      ),
    );

    expect(
      mountain.attributes
          .firstWhere((attribute) => attribute.key == 'risk_level')
          .value,
      '注意',
    );
    expect(
      legendary.attributes
          .firstWhere((attribute) => attribute.key == 'risk_level')
          .value,
      '高',
    );
  });
}
