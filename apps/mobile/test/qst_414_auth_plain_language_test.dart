import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/core/router/app_routes.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/auth_entry_switcher.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/splash/splash_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

void main() {
  test('registration failure stays scoped to signup', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final legalAcceptance = QuestraLegalPolicy.acceptance();

    await container
        .read(authControllerProvider.notifier)
        .signUp(
          email: 'sample@example.com',
          password: 'Password123',
          nickname: 'Sample',
          legalAcceptance: LegalAcceptance(
            eligibilityVersion: legalAcceptance.eligibilityVersion,
            termsVersion: legalAcceptance.termsVersion,
            privacyVersion: legalAcceptance.privacyVersion,
            aiDisclosureVersion: legalAcceptance.aiDisclosureVersion,
            regionCode: legalAcceptance.regionCode,
            minimumAgeConfirmed: false,
            acceptedAt: legalAcceptance.acceptedAt,
          ),
        );

    final auth = container.read(authControllerProvider);
    expect(auth.errorContext, AuthErrorContext.signup);
    expect(auth.errorMessage, isNot(contains('10回連続')));
  });

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
    expect(find.textContaining('再読み込みで消え'), findsOneWidget);
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

  testWidgets(
    'signup does not inherit login failures but shows signup errors',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const LoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.signup,
            builder: (_, _) => const SignupScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith(_AuthErrorFixture.new)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      (container.read(authControllerProvider.notifier) as _AuthErrorFixture)
          .failLogin();
      await tester.pump();
      expect(find.textContaining('10回連続で失敗'), findsOneWidget);

      await tester.tap(find.text('新規登録'));
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        final checkbox = find.byType(Checkbox).at(index);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
      }
      final continueButton = find.text('アカウント情報を入力');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('10回連続で失敗'), findsNothing);

      (container.read(authControllerProvider.notifier) as _AuthErrorFixture)
          .failSignup();
      await tester.pump();
      expect(find.text('アカウントを作成できませんでした。'), findsOneWidget);
      expect(find.textContaining('10回連続で失敗'), findsNothing);
    },
  );

  test('connected signup notice does not claim a verified account exists', () {
    final notice = LoginScreen.registrationNotice(isConnected: true);
    expect(notice, isNot(contains('アカウントを作成しました。')));
    expect(notice, contains('確認メールのリンク'));
    expect(notice, contains('確認メールが届かない方'));
    expect(notice, isNot(contains('パスワードを忘れた方')));
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

class _AuthErrorFixture extends AuthController {
  @override
  AuthState build() => const AuthState();

  void failLogin() {
    state = state.copyWith(
      errorMessage: 'ログインIDまたはパスワードを確認してください。10回連続で失敗すると30分間ログインできません。',
      errorContext: AuthErrorContext.login,
    );
  }

  void failSignup() {
    state = state.copyWith(
      errorMessage: 'アカウントを作成できませんでした。',
      errorContext: AuthErrorContext.signup,
    );
  }
}
