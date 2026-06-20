import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/tagging/ai_tag_service.dart';
import 'package:questra/features/tagging/tag_model.dart';
import 'package:questra/features/tagging/tag_repository.dart';
import 'package:questra/features/tagging/tagging_service.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('local AI tag service creates domain tags from Quest text', () async {
    const service = LocalAiTagService();

    final tags = await service.generateTags(
      const TaggingInput(
        ownerId: 'user-1',
        entityType: TagEntityType.quest,
        entityId: 'quest-1',
        title: '富士山に登る',
        body: '日本で山登りの準備をする',
      ),
    );

    expect(tags.map((tag) => tag.name), containsAll(['Quest', 'Travel']));
    expect(tags.map((tag) => tag.name), contains('Mountain'));
    expect(tags.length, greaterThanOrEqualTo(3));
  });

  test('tagging service saves tags and exposes stats/search', () async {
    final repository = InMemoryTagRepository();
    final tagging = TaggingService(
      aiTagService: const LocalAiTagService(),
      repository: repository,
    );
    final quest = Quest(
      id: '00000000-0000-0000-0000-000000000101',
      title: '英語を話せるようになる',
      description: '毎日少しずつ会話練習をする',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      category: '学習',
    );

    final result = await tagging.tagQuest(ownerId: 'user-1', quest: quest);
    final stats = await tagging.stats(ownerId: 'user-1');
    final search = await tagging.searchByTag(
      ownerId: 'user-1',
      query: 'Language',
    );

    expect(result.entityType, TagEntityType.quest);
    expect(result.tags.map((tag) => tag.name), contains('Language'));
    expect(stats.map((stat) => stat.tag.name), contains('Language'));
    expect(search, hasLength(1));
    expect(search.first.entityId, quest.id);
  });
}
