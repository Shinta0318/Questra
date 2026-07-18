import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_form_screen.dart';

void main() {
  testWidgets('Quest create screen explains the first Quest flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: QuestFormScreen())),
    );

    expect(find.text('最初のQuestは小さく始めましょう'), findsOneWidget);
    expect(find.text('1. 叶えたい景色を一文で置く'), findsOneWidget);
    expect(find.text('2. 理由や背景を短く残す'), findsOneWidget);
    expect(find.text('3. 保存後、Arcガイドから最初のMissionを選ぶ'), findsOneWidget);
    expect(find.text('まずは一文で大丈夫です。'), findsOneWidget);
    expect(
      find.text('保存後にArcガイドとMission候補を生成します。候補はあとで採用・編集できます。'),
      findsOneWidget,
    );
  });

  testWidgets('Quest create screen gives a clear title prompt', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: QuestFormScreen())),
    );

    final saveAction = find.text('Questを保存');
    await tester.ensureVisible(saveAction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(saveAction);
    await tester.pump();
    await tester.pump();

    expect(find.text('Quest名を一文で入力してください。'), findsOneWidget);
  });
}
