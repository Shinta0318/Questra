import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/guild/guild_discovery_model.dart';
import 'package:questra/features/guild/guild_discovery_ranking_service.dart';

void main() {
  const service = GuildDiscoveryRankingService();
  final now = DateTime.utc(2026, 7, 25);

  test('never exposes private, unlisted, pending, or rejected Quest', () {
    final results = service.rank(
      candidates: [
        _quest(id: 'public', now: now),
        _quest(
          id: 'private',
          now: now,
          visibility: GuildDiscoveryVisibility.private,
        ),
        _quest(
          id: 'unlisted',
          now: now,
          visibility: GuildDiscoveryVisibility.unlisted,
        ),
        _quest(
          id: 'pending',
          now: now,
          moderationStatus: GuildDiscoveryModerationStatus.pending,
        ),
        _quest(
          id: 'rejected',
          now: now,
          moderationStatus: GuildDiscoveryModerationStatus.rejected,
        ),
      ],
      now: now,
    );

    expect(results.map((result) => result.quest.id), ['public']);
  });

  test('personal relevance outranks raw copy count', () {
    final relevant = _quest(
      id: 'relevant',
      now: now,
      tags: const ['旅行', '英語'],
      copyCount: 5,
    );
    final popular = _quest(
      id: 'popular',
      now: now,
      tags: const ['投資'],
      copyCount: 10000,
    );

    final results = service.rank(
      candidates: [popular, relevant],
      profile: const GuildDiscoveryProfile(preferredTags: ['旅行']),
      now: now,
    );

    expect(results.first.quest.id, 'relevant');
    expect(results.first.reason, contains('旅行'));
  });

  test('seeking companions section excludes ordinary publications', () {
    final results = service.rank(
      candidates: [
        _quest(id: 'open', now: now, seekingCompanions: true),
        _quest(id: 'closed', now: now),
      ],
      section: GuildDiscoverySection.seekingCompanions,
      now: now,
    );

    expect(results.single.quest.id, 'open');
  });

  test('respects result limit and uses recency for ties', () {
    final results = service.rank(
      candidates: [
        _quest(id: 'old', now: now, ageDays: 30),
        _quest(id: 'new', now: now),
      ],
      section: GuildDiscoverySection.recent,
      now: now,
      limit: 1,
    );

    expect(results.single.quest.id, 'new');
  });
}

GuildDiscoveryQuest _quest({
  required String id,
  required DateTime now,
  GuildDiscoveryVisibility visibility = GuildDiscoveryVisibility.public,
  GuildDiscoveryModerationStatus moderationStatus =
      GuildDiscoveryModerationStatus.approved,
  List<String> tags = const ['学習'],
  int copyCount = 0,
  int ageDays = 0,
  bool seekingCompanions = false,
}) {
  return GuildDiscoveryQuest(
    id: id,
    title: '公開Quest $id',
    summary: '公開用に整理された概要',
    authorDisplayName: 'Navigator',
    tags: tags,
    difficultyScore: 3,
    publishedAt: now.subtract(Duration(days: ageDays)),
    visibility: visibility,
    moderationStatus: moderationStatus,
    copyCount: copyCount,
    averageCompletionRate: 0.7,
    seekingCompanions: seekingCompanions,
  );
}
