import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/navigator_rank_service.dart';

void main() {
  const service = NavigatorRankService();

  test('derives every rank only from cumulative Stardust', () {
    expect(service.resolve(stardustBalance: 0).rank, NavigatorRank.novice);
    expect(service.resolve(stardustBalance: 49).rank, NavigatorRank.novice);
    expect(service.resolve(stardustBalance: 50).rank, NavigatorRank.pathfinder);
    expect(service.resolve(stardustBalance: 150).rank, NavigatorRank.stargazer);
    expect(service.resolve(stardustBalance: 300).rank, NavigatorRank.navigator);
  });

  test('reports progress and remaining Stardust within the current band', () {
    final rank = service.resolve(stardustBalance: 100);

    expect(rank.rank, NavigatorRank.pathfinder);
    expect(rank.currentThreshold, 50);
    expect(rank.nextThreshold, 150);
    expect(rank.remainingToNext, 50);
    expect(rank.progressToNext, 0.5);
  });

  test('clamps negative values and completes the maximum rank', () {
    expect(service.resolve(stardustBalance: -1).stardust, 0);
    final maximum = service.resolve(stardustBalance: 999);
    expect(maximum.isMaxRank, isTrue);
    expect(maximum.remainingToNext, 0);
    expect(maximum.progressToNext, 1);
  });

  test('maps stored cache keys', () {
    expect(service.fromStorage('navigator'), NavigatorRank.navigator);
    expect(NavigatorRank.pathfinder.storageKey, 'pathfinder');
  });
}
