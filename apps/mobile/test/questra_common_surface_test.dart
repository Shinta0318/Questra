import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/layout/questra_coming_soon_screen.dart';
import 'package:questra/widgets/layout/questra_screen_surface.dart';

void main() {
  testWidgets('screen surface preserves its content in a safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuestraScreenSurface(child: Text('共通画面'))),
      ),
    );

    expect(find.byType(SafeArea), findsOneWidget);
    expect(find.text('共通画面'), findsOneWidget);
  });

  testWidgets('Coming Soon screen exposes one clear Home action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: QuestraComingSoonScreen(
          featureName: 'Guild',
          message: '同じQuestを持つ仲間とつながる機能を準備しています。',
        ),
      ),
    );

    expect(find.text('Guild'), findsWidgets);
    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Homeへ戻る'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
