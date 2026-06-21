import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_timeline_service.dart';

void main() {
  test('groups Trails by day in newest-first chronological order', () {
    final service = TrailTimelineService();
    final older = Trail(
      title: '古いTrail',
      summary: '昨日の記録',
      content: 'content',
      trailType: TrailType.manualNote,
      createdAt: DateTime(2026, 6, 20, 8),
    );
    final newer = Trail(
      title: '新しいTrail',
      summary: '今日の記録',
      content: 'content',
      trailType: TrailType.arcReflection,
      createdAt: DateTime(2026, 6, 21, 9),
    );
    final newestSameDay = Trail(
      title: 'さらに新しいTrail',
      summary: '同じ日の記録',
      content: 'content',
      trailType: TrailType.questRecord,
      createdAt: DateTime(2026, 6, 21, 11),
    );

    final days = service.groupByDay([older, newer, newestSameDay]);

    expect(days, hasLength(2));
    expect(days.first.trails.map((trail) => trail.title), [
      'さらに新しいTrail',
      '新しいTrail',
    ]);
    expect(days.last.trails.single.title, '古いTrail');
  });
}
