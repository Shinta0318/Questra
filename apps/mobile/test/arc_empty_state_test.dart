import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/arc/arc_empty_state.dart';

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
}
