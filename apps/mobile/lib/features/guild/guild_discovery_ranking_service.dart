import 'dart:math' as math;

import 'guild_discovery_model.dart';

class GuildDiscoveryRankingService {
  const GuildDiscoveryRankingService();

  List<GuildDiscoveryResult> rank({
    required Iterable<GuildDiscoveryQuest> candidates,
    GuildDiscoveryProfile profile = const GuildDiscoveryProfile(),
    GuildDiscoverySection section = GuildDiscoverySection.recommended,
    DateTime? now,
    int limit = 20,
  }) {
    if (limit <= 0) return const <GuildDiscoveryResult>[];

    final evaluatedAt = now ?? DateTime.now();
    final normalizedPreferences = profile.preferredTags
        .map(_normalize)
        .where((tag) => tag.isNotEmpty)
        .toSet();

    final results =
        candidates
            .where((quest) => quest.canAppearInDiscovery)
            .where(
              (quest) =>
                  section != GuildDiscoverySection.seekingCompanions ||
                  quest.seekingCompanions,
            )
            .map((quest) {
              final matchingTags = quest.tags
                  .map(_normalize)
                  .where(normalizedPreferences.contains)
                  .toSet();
              final relevance = normalizedPreferences.isEmpty
                  ? 0.35
                  : matchingTags.length / normalizedPreferences.length;
              final ageDays = math.max(
                0,
                evaluatedAt.difference(quest.publishedAt).inDays,
              );
              final recency = 1 / (1 + (ageDays / 30));
              final completionSignal = quest.averageCompletionRate.clamp(
                0.0,
                1.0,
              );
              final reviewSignal = quest.reviewScore == null
                  ? 0.5
                  : (quest.reviewScore! / 5).clamp(0.0, 1.0);
              final evidenceWeight = math.min(1.0, quest.reviewCount / 10);
              final usefulness =
                  (completionSignal * 0.6) +
                  ((reviewSignal * evidenceWeight +
                          0.5 * (1 - evidenceWeight)) *
                      0.4);
              final difficultyFit = profile.preferredDifficulty == null
                  ? 0.5
                  : 1 -
                        (quest.difficultyScore - profile.preferredDifficulty!)
                                .abs() /
                            4;
              final boundedPopularity =
                  math.log(quest.copyCount + 1) / math.log(10001);

              final score = switch (section) {
                GuildDiscoverySection.recent => recency,
                GuildDiscoverySection.trending =>
                  recency * 0.35 + usefulness * 0.35 + boundedPopularity * 0.30,
                GuildDiscoverySection.seekingCompanions =>
                  relevance * 0.40 + recency * 0.25 + usefulness * 0.35,
                GuildDiscoverySection.missionLibrary =>
                  relevance * 0.50 + usefulness * 0.35 + recency * 0.15,
                GuildDiscoverySection.recommended =>
                  relevance * 0.50 +
                      usefulness * 0.25 +
                      difficultyFit.clamp(0.0, 1.0) * 0.15 +
                      recency * 0.10,
              };

              return GuildDiscoveryResult(
                quest: quest,
                score: score,
                reason: _reason(
                  matchingTags: matchingTags,
                  section: section,
                  seekingCompanions: quest.seekingCompanions,
                ),
              );
            })
            .toList()
          ..sort((left, right) {
            final scoreOrder = right.score.compareTo(left.score);
            if (scoreOrder != 0) return scoreOrder;
            return right.quest.publishedAt.compareTo(left.quest.publishedAt);
          });

    return List<GuildDiscoveryResult>.unmodifiable(results.take(limit));
  }

  String _normalize(String value) => value.trim().toLowerCase();

  String _reason({
    required Set<String> matchingTags,
    required GuildDiscoverySection section,
    required bool seekingCompanions,
  }) {
    if (matchingTags.isNotEmpty) {
      return '${matchingTags.take(2).join('・')}の関心に近いQuestです';
    }
    if (section == GuildDiscoverySection.seekingCompanions &&
        seekingCompanions) {
      return '同じ航路を進む仲間を募集しています';
    }
    if (section == GuildDiscoverySection.recent) {
      return '最近公開された新しいQuestです';
    }
    return '達成状況と新しさをもとに選びました';
  }
}
