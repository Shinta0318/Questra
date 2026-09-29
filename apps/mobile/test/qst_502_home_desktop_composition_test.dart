import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/home/home_screen.dart';

void main() {
  testWidgets('Home constrains the journey column on wide desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('home-content-list')), findsOneWidget);
    expect(tester.getSize(find.byType(ListView).first).width, 920);
    expect(find.text('進行中のQuest'), findsNothing);
    expect(find.text('最近のTrail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home keeps the journey column fluid on compact mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getSize(find.byType(ListView).first).width, 390);
    expect(tester.takeException(), isNull);
  });
}
