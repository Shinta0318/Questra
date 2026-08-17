import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigatorRankServiceProvider = Provider<NavigatorRankService>(
  (ref) => const NavigatorRankService(),
);

enum NavigatorRank { novice, pathfinder, stargazer, navigator }

class NavigatorRankState {
  const NavigatorRankState({
    required this.rank,
    required this.label,
    required this.description,
    required this.stardust,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.progressToNext,
  });

  final NavigatorRank rank;
  final String label;
  final String description;
  final int stardust;
  final int currentThreshold;
  final int? nextThreshold;
  final double progressToNext;

  bool get isMaxRank => nextThreshold == null;

  int get remainingToNext => nextThreshold == null
      ? 0
      : (nextThreshold! - stardust).clamp(0, nextThreshold!);
}

class NavigatorRankService {
  const NavigatorRankService();

  static const Map<NavigatorRank, int> thresholds = {
    NavigatorRank.novice: 0,
    NavigatorRank.pathfinder: 50,
    NavigatorRank.stargazer: 150,
    NavigatorRank.navigator: 300,
  };

  NavigatorRankState resolve({required int stardustBalance}) {
    final stardust = stardustBalance < 0 ? 0 : stardustBalance;
    final rank = _rankFor(stardust);
    final currentThreshold = thresholds[rank]!;
    final nextRank = rank == NavigatorRank.navigator
        ? null
        : NavigatorRank.values[rank.index + 1];
    final nextThreshold = nextRank == null ? null : thresholds[nextRank];
    final progress = nextThreshold == null
        ? 1.0
        : ((stardust - currentThreshold) / (nextThreshold - currentThreshold))
              .clamp(0, 1)
              .toDouble();

    return NavigatorRankState(
      rank: rank,
      label: _labelFor(rank),
      description: _descriptionFor(rank),
      stardust: stardust,
      currentThreshold: currentThreshold,
      nextThreshold: nextThreshold,
      progressToNext: progress,
    );
  }

  NavigatorRank fromStorage(String value) {
    return NavigatorRank.values.firstWhere(
      (rank) => rank.storageKey == value,
      orElse: () => NavigatorRank.novice,
    );
  }

  NavigatorRank _rankFor(int stardust) {
    if (stardust >= thresholds[NavigatorRank.navigator]!) {
      return NavigatorRank.navigator;
    }
    if (stardust >= thresholds[NavigatorRank.stargazer]!) {
      return NavigatorRank.stargazer;
    }
    if (stardust >= thresholds[NavigatorRank.pathfinder]!) {
      return NavigatorRank.pathfinder;
    }
    return NavigatorRank.novice;
  }

  String _labelFor(NavigatorRank rank) {
    return switch (rank) {
      NavigatorRank.novice => '見習い航海者',
      NavigatorRank.pathfinder => '航路の開拓者',
      NavigatorRank.stargazer => '星を読む人',
      NavigatorRank.navigator => 'ナビゲーター',
    };
  }

  String _descriptionFor(NavigatorRank rank) {
    return switch (rank) {
      NavigatorRank.novice => '最初の星図を描きはじめた航海者です。',
      NavigatorRank.pathfinder => '行動の積み重ねが、新しい航路を照らしています。',
      NavigatorRank.stargazer => '多くの一歩を重ね、星の流れを読めるようになりました。',
      NavigatorRank.navigator => '積み重ねた航路が、確かなNavigatorの証になっています。',
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
