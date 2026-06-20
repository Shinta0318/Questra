import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/stardust_service.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = StardustService();

  test('resolves Stardust balance display state', () {
    final empty = service.resolve(0);
    final active = service.resolve(120);

    expect(empty.description, contains('Quest'));
    expect(active.balance, 120);
    expect(active.label, '星屑の航路');
  });

  test('awards Stardust from approved MVP actions', () {
    final trail = Trail(
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

    expect(service.forQuest(ArcMemorySourceType.questCreated).amount, 10);
    expect(service.forQuest(ArcMemorySourceType.questUpdated).amount, 0);
    expect(service.forMission(ArcMemorySourceType.missionCompleted).amount, 8);
    expect(
      service.forTrail(reflection).amount,
      greaterThan(service.forTrail(trail).amount),
    );
    expect(service.forArcConversation().amount, 1);
  });
}
