import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/guild/guild_screen.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/mission/mission_screen.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';
import 'package:questra/features/profile/profile_screen.dart';
import 'package:questra/features/quest/quest_screen.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Quest': const QuestScreen(),
    'Mission': const MissionScreen(),
    'Trail': const TrailScreen(),
    'Guild': const GuildScreen(),
    'Arc Chat': const ArcScreen(),
    'Profile': const ProfileScreen(),
    'Onboarding': const OnboardingScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders at compact width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp(home: entry.value)),
      );
      await tester.pump();

      final exception = tester.takeException();
      if (exception is FlutterError) {
        fail(exception.toStringDeep());
      }
      expect(exception, isNull);
    });
  }

  testWidgets('Arc input remains above the keyboard inset', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ArcScreen())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byType(TextField)).dy,
      lessThanOrEqualTo(400),
    );
  });

  testWidgets('Trail create sheet scrolls above the keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TrailScreen())),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Trailを残す'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Trailを残す'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
