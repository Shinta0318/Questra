import '../../core/performance/performance_limits.dart';
import 'arc_memory_model.dart';

class ArcMemoryRetrievalService {
  const ArcMemoryRetrievalService();

  List<ArcMemory> retrieve({
    required List<ArcMemory> memories,
    required String query,
    Set<String> questIds = const {},
    int limit = QuestraPerformanceLimits.arcChatMemoryContextLimit,
    bool includeSensitive = false,
    DateTime? now,
  }) {
    if (limit <= 0) {
      return const [];
    }

    final referenceTime = now ?? DateTime.now();
    final terms = _searchTerms(query);
    final ranked =
        memories
            .where((memory) => memory.userVisible)
            .where(
              (memory) =>
                  includeSensitive ||
                  memory.sensitivityLevel != SensitivityLevel.sensitive,
            )
            .map(
              (memory) => (
                memory: memory,
                score: _score(
                  memory,
                  terms: terms,
                  questIds: questIds,
                  now: referenceTime,
                ),
              ),
            )
            .toList()
          ..sort((a, b) {
            final score = b.score.compareTo(a.score);
            if (score != 0) {
              return score;
            }
            return b.memory.createdAt.compareTo(a.memory.createdAt);
          });

    return ranked
        .take(limit)
        .map((entry) => entry.memory)
        .toList(growable: false);
  }

  double _score(
    ArcMemory memory, {
    required Set<String> terms,
    required Set<String> questIds,
    required DateTime now,
  }) {
    var score = memory.importanceScore * 3;
    if (memory.questId != null && questIds.contains(memory.questId)) {
      score += 3;
    }

    final searchable = '${memory.title} ${memory.content}'.toLowerCase();
    for (final term in terms) {
      if (searchable.contains(term)) {
        score += term.length >= 5 ? 2 : 1;
      }
    }

    final age = now.difference(memory.updatedAt);
    final ageInDays = age.isNegative ? 0 : age.inHours / 24;
    score += 1 / (1 + ageInDays / 30);
    return score;
  }

  Set<String> _searchTerms(String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      return const {};
    }

    final terms = normalized
        .split(RegExp(r'[\s、。,.!?！？:;]+'))
        .where((term) => term.length >= 2)
        .toSet();
    if (normalized.length <= 40) {
      terms.add(normalized);
    }
    return terms;
  }
}
