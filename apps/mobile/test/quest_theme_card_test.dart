import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_theme_card.dart';

void main() {
  const resolver = QuestThemeResolver();

  Quest quest({
    required String title,
    String category = '冒険',
    String description = '説明',
  }) {
    return Quest(
      title: title,
      description: description,
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: category,
    );
  }

  test('resolves learning Quest theme from Japanese category', () {
    final theme = resolver.resolve(quest(title: '英語を話せるようになる', category: '学習'));

    expect(theme.name, 'Learning Voyage');
    expect(theme.icon, Icons.menu_book_outlined);
    expect(theme.dnaLabel, contains('学習'));
    expect(theme.arcHint, contains('知識'));
  });

  test('resolves builder Quest theme from launch language', () {
    final theme = resolver.resolve(
      quest(title: 'Questraをローンチする', category: '起業'),
    );

    expect(theme.name, 'Builder Route');
    expect(theme.icon, Icons.rocket_launch_outlined);
    expect(theme.dnaLabel, contains('仕事'));
  });

  test('falls back to a neutral personal Quest theme', () {
    final theme = resolver.resolve(quest(title: 'まだ名前のない挑戦', category: 'その他'));

    expect(theme.name, 'Personal Quest');
    expect(theme.dnaLabel, 'Quest DNA');
    expect(theme.arcHint, contains('願い'));
  });
}
