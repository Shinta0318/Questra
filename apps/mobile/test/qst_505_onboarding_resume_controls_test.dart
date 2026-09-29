import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/onboarding/onboarding_draft_repository.dart';
import 'package:questra/features/onboarding/onboarding_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';

void main() {
  testWidgets('three-step onboarding exposes progress and Back', (
    tester,
  ) async {
    final repository = InMemoryOnboardingDraftRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ステップ 1 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-back')), findsNothing);
    expect(find.text('後で設定'), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pump();
    expect(find.text('ステップ 2 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-back')), findsOneWidget);

    await tester.tap(find.text('次へ'));
    await tester.pump();
    expect(find.text('ステップ 3 / 3'), findsOneWidget);
    expect(find.text('最初のQuest'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pump();
    expect(find.text('ステップ 2 / 3'), findsOneWidget);
  });

  testWidgets('unfinished onboarding resumes the owner-scoped draft', (
    tester,
  ) async {
    final repository = InMemoryOnboardingDraftRepository();
    await repository.save(
      'onboarding-user',
      OnboardingDraft(
        step: 4,
        nickname: 'シンタ',
        arcName: 'Arc',
        questWish: 'シンガポールへ行きたい',
        updatedAt: DateTime.now(),
      ),
    );
    final container = _container(repository);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ステップ 3 / 3'), findsOneWidget);
    expect(find.text('最初のQuest'), findsOneWidget);
    expect(find.text('シンガポールへ行きたい'), findsOneWidget);
  });

  testWidgets('Skip completes onboarding without inventing a Quest', (
    tester,
  ) async {
    final repository = InMemoryOnboardingDraftRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/arc',
          builder: (_, _) => const Scaffold(body: Text('Arc destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('後で設定'));
    await tester.pumpAndSettle();

    expect(find.text('Arc destination'), findsOneWidget);
    expect(
      container.read(authControllerProvider).profile?.onboardingCompleted,
      isTrue,
    );
    expect(container.read(questControllerProvider), isEmpty);
    expect(await repository.load('onboarding-user'), isNull);
  });
}

ProviderContainer _container(InMemoryOnboardingDraftRepository repository) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_IncompleteAuthController.new),
      onboardingDraftRepositoryProvider.overrideWithValue(repository),
      experienceSettingsRepositoryProvider.overrideWithValue(
        InMemoryExperienceSettingsRepository(),
      ),
    ],
  );
}

class _IncompleteAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'onboarding-user',
      email: 'onboarding@example.invalid',
      nickname: '旅人',
      legalAcceptanceCurrent: true,
    ),
  );
}
