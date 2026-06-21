import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/guild/guild_quest_matching_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  const service = GuildQuestMatchingService();

  test('ranks public and guild Quests by category and terms', () {
    final source = _quest(
      title: '富士山に登る',
      category: '挑戦',
      visibility: QuestVisibility.guild,
    );
    final publicMatch = _quest(
      title: '山に登る準備をする',
      category: '挑戦',
      visibility: QuestVisibility.public,
    );
    final guildMatch = _quest(
      title: '英語で旅の会話をする',
      category: '学習',
      visibility: QuestVisibility.guild,
    );

    final matches = service.rank(
      sourceQuest: source,
      candidates: [publicMatch, guildMatch],
    );

    expect(matches.first.questId, publicMatch.id);
    expect(matches.first.reason, contains('カテゴリ'));
  });

  test('does not expose private Quest candidates', () {
    final source = _quest(
      title: '英語を話せるようになる',
      category: '学習',
      visibility: QuestVisibility.guild,
    );
    final privateQuest = _quest(
      title: '英語面接の準備',
      category: '学習',
      visibility: QuestVisibility.private,
    );

    final matches = service.rank(
      sourceQuest: source,
      candidates: [privateQuest],
    );

    expect(matches, isEmpty);
  });
}

Quest _quest({
  required String title,
  required String category,
  required QuestVisibility visibility,
}) {
  return Quest(
    title: title,
    description: 'hidden detail',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: visibility,
    category: category,
  );
}
