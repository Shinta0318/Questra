import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test('Trail repository returns stable non-overlapping pages', () async {
    final repository = InMemoryTrailRepository();
    final base = DateTime.utc(2026, 9, 1);
    for (var index = 0; index < 45; index++) {
      await repository.save(
        ownerId: 'owner-a',
        trail: Trail(
          id: 'trail-${index.toString().padLeft(2, '0')}',
          questId: 'quest-a',
          missionId: 'mission-a',
          title: 'Trail $index',
          summary: '記録 $index',
          content: '内容 $index',
          trailType: TrailType.missionRecord,
          createdAt: base.add(Duration(minutes: index)),
        ),
      );
    }

    final first = await repository.findByUser('owner-a', limit: 40);
    final second = await repository.findByUser(
      'owner-a',
      limit: 40,
      before: TrailPageCursor.fromTrail(first.last),
    );

    expect(first, hasLength(40));
    expect(second, hasLength(5));
    expect(first.first.id, 'trail-44');
    expect(second.last.id, 'trail-00');
    expect(
      first
          .map((trail) => trail.id)
          .toSet()
          .intersection(second.map((trail) => trail.id).toSet()),
      isEmpty,
    );
  });

  test('Trail pagination stays inside the requested owner boundary', () async {
    final repository = InMemoryTrailRepository();
    await repository.save(ownerId: 'owner-a', trail: _trail('trail-a'));
    await repository.save(ownerId: 'owner-b', trail: _trail('trail-b'));

    final page = await repository.findByUser('owner-a', limit: 10);

    expect(page.map((trail) => trail.id), ['trail-a']);
  });
}

Trail _trail(String id) => Trail(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: id,
  summary: id,
  content: id,
  trailType: TrailType.missionRecord,
);
