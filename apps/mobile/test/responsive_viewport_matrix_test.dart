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
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_screen.dart';
import 'package:questra/features/trail/trail_screen.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  final surfaces = <String, Widget>{
    'Home': const HomeScreen(),
    'Quest': const QuestScreen(),
    'Quest Detail': Consumer(
      builder: (context, ref, child) {
        final questId = ref.watch(questControllerProvider).first.id;
        return QuestDetailScreen(questId: questId);
      },
    ),
    'Mission': const MissionScreen(),
    'Trail': const TrailScreen(),
    'Guild': const GuildScreen(),
    'Arc': const ArcScreen(),
    'Profile': const ProfileScreen(),
    'Onboarding': const OnboardingScreen(),
  };

  final viewports = <String, Size>{
    'compact': const Size(390, 844),
    'medium': const Size(800, 900),
    'expanded': const Size(1280, 900),
  };

  for (final viewport in viewports.entries) {
    for (final surface in surfaces.entries) {
      testWidgets('${surface.key} renders at ${viewport.key} viewport', (
        tester,
      ) async {
        tester.view.physicalSize = viewport.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              questControllerProvider.overrideWith(FixtureQuestController.new),
            ],
            child: MaterialApp(home: surface.value),
          ),
        );
        await tester.pump();

        final exception = tester.takeException();
        if (exception is FlutterError) {
          fail(exception.toStringDeep());
        }
        expect(exception, isNull);
      });
    }
  }
}
