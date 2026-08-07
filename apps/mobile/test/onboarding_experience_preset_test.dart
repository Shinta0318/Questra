import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('first onboarding stays focused on the first Quest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          experienceSettingsRepositoryProvider.overrideWithValue(
            InMemoryExperienceSettingsRepository(),
          ),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('次へ'));
      await tester.pump();
    }

    expect(find.text('最初のQuest'), findsOneWidget);
    expect(find.text('Questraの演出'), findsNothing);
    expect(find.text('旅の傾向'), findsNothing);
  });
}
