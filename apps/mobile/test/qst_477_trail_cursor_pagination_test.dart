import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test(
    'a newer insert cannot shift or duplicate the next Trail page',
    () async {
      final repository = InMemoryTrailRepository();
      final base = DateTime.utc(2026, 9, 20);
      final originalIds = <String>{};
      for (var index = 0; index < 45; index++) {
        final id = 'trail-${index.toString().padLeft(2, '0')}';
        originalIds.add(id);
        await repository.save(
          ownerId: 'owner-a',
          trail: _trail(id, base.add(Duration(minutes: index))),
        );
      }

      final first = await repository.findByUser('owner-a', limit: 40);
      await repository.save(
        ownerId: 'owner-a',
        trail: _trail('trail-new', base.add(const Duration(days: 1))),
      );
      final second = await repository.findByUser(
        'owner-a',
        limit: 40,
        before: TrailPageCursor.fromTrail(first.last),
      );

      final loadedIds = [...first, ...second].map((trail) => trail.id).toList();
      expect(loadedIds.toSet(), originalIds);
      expect(loadedIds, hasLength(originalIds.length));
      expect(loadedIds, isNot(contains('trail-new')));
    },
  );

  test('cursor uses Trail id as a stable tie-breaker', () async {
    final repository = InMemoryTrailRepository();
    final createdAt = DateTime.utc(2026, 9, 20);
    for (var index = 0; index < 45; index++) {
      await repository.save(
        ownerId: 'owner-a',
        trail: _trail('trail-${index.toString().padLeft(2, '0')}', createdAt),
      );
    }

    final first = await repository.findByUser('owner-a', limit: 40);
    final second = await repository.findByUser(
      'owner-a',
      limit: 40,
      before: TrailPageCursor.fromTrail(first.last),
    );

    expect(first.first.id, 'trail-44');
    expect(first.last.id, 'trail-05');
    expect(second.map((trail) => trail.id), [
      'trail-04',
      'trail-03',
      'trail-02',
      'trail-01',
      'trail-00',
    ]);
  });
}

Trail _trail(String id, DateTime createdAt) => Trail(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
  createdAt: createdAt,
);
