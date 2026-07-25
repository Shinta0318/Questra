import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding offers three experience presets', (tester) async {
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

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('次へ'));
      await tester.pump();
    }

    expect(find.text('Questraの演出'), findsOneWidget);
    expect(find.text('フル体験'), findsOneWidget);
    expect(find.text('静かな体験'), findsOneWidget);
    expect(find.text('シンプル'), findsOneWidget);
  });
}
