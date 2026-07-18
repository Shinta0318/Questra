import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/settings/widgets/settings_tutorial_card.dart';

void main() {
  testWidgets('exposes tutorial and Quest navigation actions', (tester) async {
    var replayCount = 0;
    var returnCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsTutorialCard(
            onReplay: () => replayCount += 1,
            onReturnToQuest: () => returnCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('Arcチュートリアル'), findsOneWidget);
    expect(find.text('Arcチュートリアルを再表示'), findsOneWidget);
    expect(find.text('Questへ戻る'), findsOneWidget);

    await tester.tap(find.text('Arcチュートリアルを再表示'));
    await tester.tap(find.text('Questへ戻る'));

    expect(replayCount, 1);
    expect(returnCount, 1);
  });
}
