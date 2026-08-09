import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/trail/trail_highlight_service.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_timeline_service.dart';
import 'package:questra/features/trail/trail_timeline_widget.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

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

  testWidgets('timeline shows summary metrics and day counts', (tester) async {
    final reflection = Trail(
      title: 'Reflection Trail',
      summary: '今日の学び',
      content: 'content',
      trailType: TrailType.arcReflection,
      createdAt: DateTime(2026, 6, 21, 9),
    );
    final questTrail = Trail(
      title: 'Quest Trail',
      summary: 'Questの前進',
      content: 'content',
      trailType: TrailType.questRecord,
      createdAt: DateTime(2026, 6, 21, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrailTimelineWidget(
              trails: [reflection, questTrail],
              attachments: const {},
              highlights: {
                reflection.id: TrailHighlight(
                  trailId: reflection.id,
                  score: 12,
                  reason: 'Reflectionが深いTrailです。',
                  isStarMemoryCandidate: true,
                ),
              },
              onCreateTrail: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Trail'), findsOneWidget);
    expect(find.text('振り返り'), findsOneWidget);
    expect(find.text('Star候補'), findsOneWidget);
    expect(find.text('画像'), findsOneWidget);
    expect(find.text('Trail 2件'), findsOneWidget);
    expect(find.text('Trailを残す'), findsOneWidget);
  });
}
