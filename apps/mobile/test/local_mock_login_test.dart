import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/login_screen.dart';

void main() {
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
}
