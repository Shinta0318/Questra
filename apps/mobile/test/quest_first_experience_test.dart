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

    expect(find.text('Arcと話しながら決める'), findsOneWidget);
    expect(find.text('迷ったら、今見たい景色から'), findsOneWidget);
    expect(find.text('叶えたい状態を一文にします。あとから変更できます。'), findsOneWidget);
    expect(find.text('いつ頃までに叶えたい？'), findsOneWidget);
    expect(find.text('保存後、Arcが道筋と最初のMission候補を描きます。'), findsOneWidget);
  });

  testWidgets('Quest create screen gives a clear title prompt', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: QuestFormScreen())),
    );

    final saveAction = find.text('保存して航路を描く');
    await tester.ensureVisible(saveAction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(saveAction);
    await tester.pump();
    await tester.pump();

    expect(find.text('Quest名を入力してください。'), findsOneWidget);
  });
}
