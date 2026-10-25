import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/router/auth_route_guard.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/confirm_email_help_screen.dart';
import 'package:questra/features/auth/login_screen.dart';

void main() {
  test('confirmation help stays public without revealing account state', () {
    expect(
      AuthRouteGuard.redirect(
        auth: const AuthState(),
        location: Uri.parse(AppRoutes.confirmEmailHelp),
        persistenceAvailable: true,
      ),
      isNull,
    );
  });

  testWidgets('login opens confirmation help on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: AppRoutes.confirmEmailHelp,
          builder: (_, _) => const ConfirmEmailHelpScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          confirmationEmailAvailableProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final help = find.text('確認メールが届かない方');
    await tester.ensureVisible(help);
    await tester.tap(help);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.confirmEmailHelp,
    );
    expect(find.text('メールが届かないとき'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local mock cannot claim an email was sent', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          confirmationEmailAvailableProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: ConfirmEmailHelpScreen()),
      ),
    );
    expect(find.textContaining('このモックでは確認メールを送信できません'), findsOneWidget);
    expect(find.text('確認メールを再送する'), findsNothing);
  });

  testWidgets('resend form remains reachable with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          confirmationEmailAvailableProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(home: ConfirmEmailHelpScreen()),
      ),
    );
    final button = find.text('確認メールを再送する');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend validates email and prevents an immediate repeat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        confirmationEmailAvailableProvider.overrideWith((ref) => true),
        authControllerProvider.overrideWith(_ResendFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.confirmEmailHelp,
      routes: [
        GoRoute(
          path: AppRoutes.confirmEmailHelp,
          builder: (_, _) => const ConfirmEmailHelpScreen(),
        ),
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
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

    final button = find.text('確認メールを再送する');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('メールアドレスを入力してください。'), findsOneWidget);
    expect(
      (container.read(authControllerProvider.notifier) as _ResendFixture)
          .requested,
      isEmpty,
    );

    await tester.enterText(find.byType(TextFormField), 'name@gmai.com');
    await tester.pump();
    final correction = find.text('@gmail.com に修正する');
    await tester.ensureVisible(correction);
    await tester.tap(correction);
    await tester.pump();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    final fixture =
        container.read(authControllerProvider.notifier) as _ResendFixture;
    expect(fixture.requested, ['name@gmail.com']);
    expect(find.textContaining('再送を受け付けました'), findsOneWidget);
    expect(find.textContaining('秒後に再送できます'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
    await tester.tap(find.textContaining('秒後に再送できます'), warnIfMissed: false);
    expect(fixture.requested, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed resend never claims an email was sent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        confirmationEmailAvailableProvider.overrideWith((ref) => true),
        authControllerProvider.overrideWith(_ResendFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final fixture =
        container.read(authControllerProvider.notifier) as _ResendFixture;
    fixture.accept = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConfirmEmailHelpScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'name@example.com');
    final button = find.text('確認メールを再送する');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(fixture.requested, ['name@example.com']);
    expect(find.textContaining('再送を受け付けました'), findsNothing);
    expect(find.textContaining('再送を受け付けられませんでした'), findsOneWidget);
    expect(find.text('確認メールを再送する'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ResendFixture extends AuthController {
  final requested = <String>[];
  bool accept = true;

  @override
  AuthState build() => const AuthState();

  @override
  Future<bool> resendSignupConfirmation({required String email}) async {
    requested.add(email);
    if (!accept) {
      state = state.copyWith(
        errorMessage: '確認メールの再送を受け付けられませんでした。',
        errorContext: AuthErrorContext.confirmation,
      );
    }
    return accept;
  }
}
