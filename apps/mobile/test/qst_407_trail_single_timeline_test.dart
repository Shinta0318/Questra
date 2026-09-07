import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_timeline_widget.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('空状態は0件統計を出さず作成CTAを一つだけ示す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrailTimelineWidget(
            trails: const [],
            attachments: const {},
            onCreateTrail: () {},
          ),
        ),
      ),
    );

    expect(find.text('まだTrailはありません'), findsOneWidget);
    expect(find.text('最初のTrailを残す'), findsOneWidget);
    expect(find.text('進捗の概要'), findsNothing);
    expect(find.text('Trail Timeline'), findsNothing);
  });

  testWidgets('20件のTrailを一つの時系列へ一度ずつ描画する', (tester) async {
    final trails = List.generate(
      20,
      (index) => Trail(
        id: 'trail-$index',
        title: '記録 $index',
        summary: '一歩進んだ',
        content: '一歩進んだ',
        trailType: TrailType.manualNote,
        createdAt: DateTime(2026, 9, 6, 12).subtract(Duration(days: index)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrailTimelineWidget(
              trails: trails,
              attachments: const {},
              onCreateTrail: () {},
              itemBuilder: (context, trail) =>
                  Text(trail.title, key: ValueKey('single-${trail.id}')),
            ),
          ),
        ),
      ),
    );

    for (final trail in trails) {
      expect(find.byKey(ValueKey('single-${trail.id}')), findsOneWidget);
    }
    expect(find.text('Trail'), findsOneWidget);
    expect(find.text('振り返り'), findsNothing);
    expect(find.text('Star候補'), findsNothing);
    expect(find.text('画像'), findsNothing);
  });
}
