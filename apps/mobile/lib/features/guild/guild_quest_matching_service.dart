import '../quest/quest_model.dart';

class GuildQuestMatch {
  const GuildQuestMatch({
    required this.questId,
    required this.title,
    required this.category,
    required this.score,
    required this.reason,
    required this.visibility,
  });

  final String questId;
  final String title;
  final String category;
  final int score;
  final String reason;
  final QuestVisibility visibility;
}

class GuildQuestMatchingService {
  const GuildQuestMatchingService();

  List<GuildQuestMatch> rank({
    required Quest sourceQuest,
    required List<Quest> candidates,
  }) {
    final sourceTerms = _terms(sourceQuest);
    final matches = <GuildQuestMatch>[];

    for (final candidate in candidates) {
      if (candidate.id == sourceQuest.id ||
          candidate.status == QuestStatus.archived ||
          candidate.visibility == QuestVisibility.private) {
        continue;
      }

      final candidateTerms = _terms(candidate);
      final overlap = sourceTerms.intersection(candidateTerms);
      final categoryMatch =
          sourceQuest.category.trim().toLowerCase() ==
          candidate.category.trim().toLowerCase();
      final score = (overlap.length * 18) + (categoryMatch ? 28 : 0);
      if (score < 18) {
        continue;
      }

      matches.add(
        GuildQuestMatch(
          questId: candidate.id,
          title: candidate.title,
          category: candidate.category,
          score: score.clamp(0, 100),
          visibility: candidate.visibility,
          reason: _reason(overlap: overlap, categoryMatch: categoryMatch),
        ),
      );
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(5).toList(growable: false);
  }

  Set<String> _terms(Quest quest) {
    final text = '${quest.title} ${quest.category}'.toLowerCase();
    return text
        .split(RegExp(r'[^a-z0-9ぁ-んァ-ヶ一-龠]+'))
        .where((term) => term.trim().length >= 2)
        .map((term) => term.trim())
        .toSet();
  }

  String _reason({required Set<String> overlap, required bool categoryMatch}) {
    if (categoryMatch && overlap.isNotEmpty) {
      return 'カテゴリとキーワードが近いQuestです。';
    }
    if (categoryMatch) {
      return '同じカテゴリのQuestです。';
    }
    return '近いキーワードを持つQuestです。';
  }
}
