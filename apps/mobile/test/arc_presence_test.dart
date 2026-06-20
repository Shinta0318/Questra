import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';
import 'package:questra/widgets/arc/arc_presence.dart';
import 'package:questra/widgets/arc/arc_widget.dart';
import 'package:questra/widgets/questra_card.dart';

void main() {
  testWidgets('renders Arc presence with card, message, and surface size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArcPresence(
            surface: ArcPresenceSurface.trail,
            emotion: ArcEmotion.support,
            message: 'Trailをあとで戻れる航路として残そう。',
          ),
        ),
      ),
    );

    final arcWidget = tester.widget<ArcWidget>(find.byType(ArcWidget));

    expect(find.byType(QuestraCard), findsOneWidget);
    expect(find.text('Trailをあとで戻れる航路として残そう。'), findsOneWidget);
    expect(arcWidget.emotion, ArcEmotion.support);
    expect(arcWidget.size, 104);
  });

  testWidgets('renders empty state with smaller Arc presence', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArcPresence(
            surface: ArcPresenceSurface.emptyState,
            emotion: ArcEmotion.lonely,
            message: 'まだ足あとがありません。',
          ),
        ),
      ),
    );

    final arcWidget = tester.widget<ArcWidget>(find.byType(ArcWidget));

    expect(find.byType(QuestraCard), findsOneWidget);
    expect(find.text('まだ足あとがありません。'), findsOneWidget);
    expect(arcWidget.emotion, ArcEmotion.lonely);
    expect(arcWidget.size, 88);
  });
}
