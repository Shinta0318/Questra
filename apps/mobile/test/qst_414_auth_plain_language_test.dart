import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/auth_entry_switcher.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/splash/splash_screen.dart';

void main() {
  testWidgets('auth entry choices remain visible on the dark journey surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.deepNavy,
          body: AuthEntrySwitcher(
            selected: AuthEntryMode.login,
            onLogin: () {},
            onSignup: () {},
          ),
        ),
      ),
    );

    final loginLabel = tester.widget<Text>(
      find.byKey(const Key('auth-entry-login-label')),
    );
    final signupLabel = tester.widget<Text>(
      find.byKey(const Key('auth-entry-signup-label')),
    );

    expect(loginLabel.style?.color, AppColors.deepNavy);
    expect(signupLabel.style?.color, AppColors.white);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('新規登録'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth entry contrast follows the selected signup state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.deepNavy,
          body: AuthEntrySwitcher(
            selected: AuthEntryMode.signup,
            onLogin: () {},
            onSignup: () {},
          ),
        ),
      ),
    );

    final loginLabel = tester.widget<Text>(
      find.byKey(const Key('auth-entry-login-label')),
    );
    final signupLabel = tester.widget<Text>(
      find.byKey(const Key('auth-entry-signup-label')),
    );

    expect(loginLabel.style?.color, AppColors.white);
    expect(signupLabel.style?.color, AppColors.deepNavy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first run shows login and signup choices without jargon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );
    await tester.pump();

    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('初めての方'), findsOneWidget);
    expect(find.textContaining('今日の一歩'), findsOneWidget);
    expect(find.textContaining('Mission'), findsNothing);
    expect(find.textContaining('Trail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login exposes signup in the first viewport and opens it once', (
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
          path: AppRoutes.signup,
          builder: (_, _) => const SignupScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    final signup = find.text('新規登録');
    expect(signup, findsOneWidget);
    expect(signup.hitTestable(), findsOneWidget);
    await tester.tap(signup);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, AppRoutes.signup);
    expect(find.text('はじめに確認すること'), findsNothing);
    expect(find.textContaining('年齢とデータの扱い'), findsOneWidget);
  });

  testWidgets('login remains scrollable with large text on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.text('ログインIDまたはメールアドレス'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
