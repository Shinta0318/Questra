import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/onboarding/onboarding_draft_repository.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('first onboarding stays focused on the first Quest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthFixture.new),
          onboardingDraftRepositoryProvider.overrideWithValue(
            InMemoryOnboardingDraftRepository(),
          ),
          experienceSettingsRepositoryProvider.overrideWithValue(
            InMemoryExperienceSettingsRepository(),
          ),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (var step = 0; step < 2; step++) {
      final nextButton = find.text('次へ');
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pump();
    }

    expect(find.text('最初のQuest'), findsOneWidget);
    expect(find.text('Questraの演出'), findsNothing);
    expect(find.text('旅の傾向'), findsNothing);
  });
}

class _AuthFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'onboarding-experience-user',
      email: 'onboarding-experience@example.invalid',
      nickname: '旅人',
    ),
  );
}
