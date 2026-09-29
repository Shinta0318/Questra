import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/arc/arc_empty_state.dart';
import 'package:questra/widgets/arc/arc_widget.dart';

void main() {
  testWidgets('ArcEmptyState shows guidance and a single action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArcEmptyState(
            title: 'まだQuestがありません',
            message: '最初のQuestを灯しましょう。',
            actionLabel: 'Questを作成',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('まだQuestがありません'), findsOneWidget);
    expect(find.text('最初のQuestを灯しましょう。'), findsOneWidget);
    expect(find.text('Questを作成'), findsOneWidget);

    await tester.tap(find.text('Questを作成'));
    expect(tapped, isTrue);
  });

  testWidgets('ArcEmptyState remains compact and avoids repeated filler copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ArcEmptyState(
                title: 'まだTrailはありません',
                message: '今日進んだことを、短い言葉から残してみよう。',
                actionLabel: '最初のTrailを残す',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ここには、あなたの航路が少しずつ集まっていきます。'), findsNothing);
    expect(tester.takeException(), isNull);
    final arc = tester.widget<ArcWidget>(find.byType(ArcWidget));
    expect(arc.size, 68);
    expect(arc.showSpeechBubble, isFalse);
  });
}
