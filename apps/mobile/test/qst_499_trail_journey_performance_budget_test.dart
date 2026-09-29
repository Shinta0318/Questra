import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/performance_limits.dart';
import 'package:questra/features/trail/trail_journey_projection.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test('Trail parent projection stays within the loaded-item frame budget', () {
    final trails = List.generate(
      QuestraPerformanceLimits.trailLoadedItemBudget,
      (index) => _trail(
        'trail-$index',
        questId: index.isEven ? 'quest-a' : 'quest-b',
        missionId: index % 4 == 0 ? 'mission-a' : 'mission-b',
      ),
    );

    final stopwatch = Stopwatch()..start();
    final projection = projectTrailJourney(
      trails,
      questId: 'quest-a',
      missionId: 'mission-a',
    );
    stopwatch.stop();

    expect(projection.trails, hasLength(100));
    expect(projection.trailIds, hasLength(100));
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(QuestraPerformanceLimits.trailJourneyProjectionBudgetMs),
    );
  });

  test('Trail repository page remains bounded and owner scoped', () async {
    final repository = InMemoryTrailRepository();
    final base = DateTime.utc(2026, 9, 21);
    for (var index = 0; index < 500; index++) {
      await repository.save(
        ownerId: index.isEven ? 'owner-a' : 'owner-b',
        trail: _trail(
          'trail-$index',
          questId: 'quest-a',
          missionId: 'mission-a',
          createdAt: base.add(Duration(minutes: index)),
        ),
      );
    }

    final page = await repository.findByUser('owner-a');

    expect(page, hasLength(QuestraPerformanceLimits.trailListLimit));
    expect(
      page.every((trail) => int.parse(trail.id.split('-').last).isEven),
      isTrue,
    );
  });
}

Trail _trail(
  String id, {
  required String questId,
  required String missionId,
  DateTime? createdAt,
}) => Trail(
  id: id,
  questId: questId,
  missionId: missionId,
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
  createdAt: createdAt ?? DateTime.utc(2026, 9, 21),
);
