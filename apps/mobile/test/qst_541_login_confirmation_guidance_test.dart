import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/forgot_password_screen.dart';
import 'package:questra/features/auth/login_screen.dart';

void main() {
  testWidgets('failed login offers confirmation help without account lookup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FailedLogin.new),
        authEmailAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    final guidance = find.textContaining('登録直後なら確認メールのリンク');
    await tester.ensureVisible(guidance);
    await tester.pumpAndSettle();
    expect(guidance, findsOneWidget);
    expect(find.text('確認メールが届かない方'), findsOneWidget);
    expect(find.textContaining('パスワードを忘れた方'), findsWidgets);
    expect(find.textContaining('このアカウント'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password reset does not repeat the previous login error', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_FailedLogin.new),
        authEmailAvailableProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('パスワードを再設定'), findsOneWidget);
    expect(find.text('ログインIDまたはパスワードを確認してください。'), findsNothing);
  });
}

class _FailedLogin extends AuthController {
  @override
  AuthState build() => const AuthState(
    errorMessage: 'ログインIDまたはパスワードを確認してください。',
    errorContext: AuthErrorContext.login,
  );
}
