import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_bond_growth_service.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = ArcBondGrowthService();

  test('maps meaningful actions to deterministic Bond deltas', () {
    expect(
      service.forQuest(ArcMemorySourceType.questCreated).delta,
      greaterThan(service.forQuest(ArcMemorySourceType.questUpdated).delta),
    );
    expect(
      service.forMission(ArcMemorySourceType.missionCompleted).delta,
      greaterThan(service.forMission(ArcMemorySourceType.missionCreated).delta),
    );
    expect(service.forArcConversation().delta, 1);
  });

  test('awards reflection Trail more than regular Trail', () {
    final regular = Trail(
      title: 'Trail',
      summary: '記録',
      content: '進んだ',
      trailType: TrailType.questRecord,
    );
    final reflection = Trail(
      title: 'Reflection',
      summary: '学び',
      content: '次の一歩',
      trailType: TrailType.arcReflection,
    );

    expect(
      service.forTrail(reflection).delta,
      greaterThan(service.forTrail(regular).delta),
    );
  });

  test('caps Bond growth at the maximum score', () {
    expect(service.apply(currentScore: 98, delta: 10), 100);
  });
}
