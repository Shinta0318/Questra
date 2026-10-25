import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

void main() {
  test('local credential login does not invent an account', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .login(identifier: 'someone', password: 'password');

    final auth = container.read(authControllerProvider);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.errorContext, AuthErrorContext.localPreviewLogin);
    expect(auth.errorMessage, contains('モックを開く'));
    expect(auth.errorMessage, isNot(contains('10回')));
  });

  test('local credential login only accepts the signed-up account', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.signUp(
      email: 'preview@example.com',
      password: 'password',
      nickname: 'Navigator',
      loginId: 'preview-user',
      legalAcceptance: QuestraLegalPolicy.acceptance(),
    );
    await controller.login(identifier: 'other-user', password: 'password');
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);
    expect(
      container.read(authControllerProvider).errorMessage,
      contains('プレビュー用'),
    );

    await controller.login(identifier: 'preview-user', password: 'wrong');
    expect(container.read(authControllerProvider).isAuthenticated, isFalse);

    await controller.login(
      identifier: 'preview@example.com',
      password: 'password',
    );
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(
      container.read(authControllerProvider).profile?.loginId,
      'preview-user',
    );
  });

  test(
    'local mock preview enters an already prepared review journey',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .enterLocalMockPreview();

      final auth = container.read(authControllerProvider);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.profile?.nickname, 'キャプテン');
      expect(auth.profile?.legalAcceptanceCurrent, isTrue);
      expect(auth.profile?.onboardingCompleted, isTrue);
      expect(auth.profile?.hasSeenOnboardingTour, isTrue);
      expect(auth.errorMessage, isNull);
    },
  );

  testWidgets('mock login opens the safe continuation immediately', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '${AppRoutes.login}?continue=%2Fhome',
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('ホームを表示中')),
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

    await tester.tap(find.text('モックを開く'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    expect(find.text('ホームを表示中'), findsOneWidget);
  });

  testWidgets('local login failure does not show Hosted email guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'someone');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    final loginButton = find.widgetWithText(FilledButton, 'ログイン');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();

    expect(find.textContaining('このプレビューには登録済みアカウントがありません'), findsOneWidget);
    expect(find.textContaining('登録直後なら確認メールのリンク'), findsNothing);
  });
}
