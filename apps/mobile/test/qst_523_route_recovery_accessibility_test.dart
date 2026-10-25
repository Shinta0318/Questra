import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_route_screen.dart';

void main() {
  testWidgets('route empty state remains readable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: QuestRouteScreen(questId: 'missing'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Questが見つかりません'), findsOneWidget);
    expect(find.textContaining('Missionを1件以上作成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
