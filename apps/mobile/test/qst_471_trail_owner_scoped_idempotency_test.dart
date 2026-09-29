import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test('same Trail ID remains isolated between owners', () async {
    final repository = InMemoryTrailRepository();
    await repository.save(
      ownerId: 'owner-a',
      trail: _trail('shared-id', 'owner A record'),
    );
    await repository.save(
      ownerId: 'owner-b',
      trail: _trail('shared-id', 'owner B record'),
    );

    final ownerA = await repository.findByUser('owner-a');
    final ownerB = await repository.findByUser('owner-b');

    expect(ownerA.single.title, 'owner A record');
    expect(ownerB.single.title, 'owner B record');
  });

  test('retry by the same owner replaces only that owner record', () async {
    final repository = InMemoryTrailRepository();
    await repository.save(
      ownerId: 'owner-a',
      trail: _trail('stable-id', 'before'),
    );
    await repository.save(
      ownerId: 'owner-a',
      trail: _trail('stable-id', 'after'),
    );

    final trails = await repository.findByUser('owner-a');
    expect(trails, hasLength(1));
    expect(trails.single.title, 'after');
  });
}

Trail _trail(String id, String title) => Trail(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: title,
  summary: title,
  content: title,
  trailType: TrailType.missionRecord,
);
