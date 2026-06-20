import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

final navigatorRankServiceProvider = Provider<NavigatorRankService>(
  (ref) => const NavigatorRankService(),
);

enum NavigatorRank { novice, pathfinder, stargazer, navigator }

class NavigatorRankState {
  const NavigatorRankState({
    required this.rank,
    required this.label,
    required this.description,
    required this.score,
    required this.progressToNext,
  });

  final NavigatorRank rank;
  final String label;
  final String description;
  final int score;
  final double progressToNext;
}

class NavigatorRankService {
  const NavigatorRankService();

  NavigatorRankState resolve({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required int bondScore,
    required int stardustBalance,
  }) {
    final completedQuests = quests
        .where((quest) => quest.status == QuestStatus.completed)
        .length;
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .length;
    final completedMissions = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;
    final reflections = trails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .length;

    final score =
        completedQuests * 18 +
        activeQuests * 8 +
        completedMissions * 5 +
        trails.length * 3 +
        reflections * 4 +
        (bondScore * 0.45).round() +
        (stardustBalance * 0.12).round();
    final rank = _rankFor(score);

    return NavigatorRankState(
      rank: rank,
      label: _labelFor(rank),
      description: _descriptionFor(rank),
      score: score,
      progressToNext: _progressToNext(score, rank),
    );
  }

  NavigatorRank fromStorage(String value) {
    return NavigatorRank.values.firstWhere(
      (rank) => rank.storageKey == value,
      orElse: () => NavigatorRank.novice,
    );
  }

  NavigatorRank _rankFor(int score) {
    if (score >= 90) {
      return NavigatorRank.navigator;
    }
    if (score >= 55) {
      return NavigatorRank.stargazer;
    }
    if (score >= 20) {
      return NavigatorRank.pathfinder;
    }
    return NavigatorRank.novice;
  }

  double _progressToNext(int score, NavigatorRank rank) {
    final (start, next) = switch (rank) {
      NavigatorRank.novice => (0, 20),
      NavigatorRank.pathfinder => (20, 55),
      NavigatorRank.stargazer => (55, 90),
      NavigatorRank.navigator => (90, 90),
    };
    if (rank == NavigatorRank.navigator) {
      return 1;
    }
    return ((score - start) / (next - start)).clamp(0, 1).toDouble();
  }

  String _labelFor(NavigatorRank rank) {
    return switch (rank) {
      NavigatorRank.novice => 'Novice',
      NavigatorRank.pathfinder => 'Pathfinder',
      NavigatorRank.stargazer => 'Stargazer',
      NavigatorRank.navigator => 'Navigator',
    };
  }

  String _descriptionFor(NavigatorRank rank) {
    return switch (rank) {
      NavigatorRank.novice => '最初の星図を描きはじめた航海者です。',
      NavigatorRank.pathfinder => 'QuestからMissionへ進む道を見つけはじめています。',
      NavigatorRank.stargazer => 'TrailとReflectionを使って、航路を読み解けています。',
      NavigatorRank.navigator => 'Arcとともに、複数の航路を導けるNavigatorです。',
    };
  }
}

extension NavigatorRankStorage on NavigatorRank {
  String get storageKey {
    return switch (this) {
      NavigatorRank.novice => 'novice',
      NavigatorRank.pathfinder => 'pathfinder',
      NavigatorRank.stargazer => 'stargazer',
      NavigatorRank.navigator => 'navigator',
    };
  }
}
