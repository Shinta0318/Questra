import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/forgot_password_screen.dart';
import 'package:questra/features/auth/reset_password_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

void main() {
  testWidgets('Forgot password asks for the linked email address', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authEmailAvailableProvider.overrideWithValue(true)],
        child: const MaterialApp(home: ForgotPasswordScreen()),
      ),
    );

    expect(find.text('パスワードを再設定'), findsOneWidget);
    expect(find.text('登録メールアドレス'), findsOneWidget);
    expect(find.text('再設定メールを送る'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.fillColor, AppColors.midnightNavy);
    expect(field.style?.color, AppColors.white);
  });

  testWidgets('Reset password requires a new password twice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authEmailAvailableProvider.overrideWithValue(true),
          authControllerProvider.overrideWith(_ReadyRecoveryController.new),
        ],
        child: const MaterialApp(home: ResetPasswordScreen()),
      ),
    );

    expect(find.text('新しいパスワードを設定'), findsOneWidget);
    expect(find.text('新しいパスワード'), findsOneWidget);
    expect(find.text('新しいパスワード（確認）'), findsOneWidget);
    expect(find.text('パスワードを更新'), findsOneWidget);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.decoration?.fillColor, AppColors.midnightNavy);
      expect(field.style?.color, AppColors.white);
    }
  });

  testWidgets('invalid recovery link cannot accept a new password', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authEmailAvailableProvider.overrideWithValue(true)],
        child: const MaterialApp(home: ResetPasswordScreen()),
      ),
    );

    expect(find.text('再設定リンクを確認'), findsOneWidget);
    expect(find.textContaining('届いた最新のリンクを開いてください'), findsOneWidget);
    expect(find.textContaining('同じブラウザー'), findsNothing);
    expect(find.text('新しいパスワード'), findsNothing);
    expect(find.text('パスワードを更新'), findsNothing);
    expect(find.text('再設定メールを送り直す'), findsOneWidget);
  });

  testWidgets('updated password awaiting sign-out cannot be entered again', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authEmailAvailableProvider.overrideWithValue(true),
          authControllerProvider.overrideWith(_PendingSignOutController.new),
        ],
        child: const MaterialApp(home: ResetPasswordScreen()),
      ),
    );

    expect(find.text('パスワードを更新しました'), findsOneWidget);
    expect(find.text('セッションを終了してログインへ'), findsOneWidget);
    expect(find.text('新しいパスワード'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('offline recovery routes never claim an email was sent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
    );
    expect(find.textContaining('このオフラインモックではメールを送信できません'), findsOneWidget);
    expect(find.text('再設定メールを送る'), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );
    expect(find.textContaining('このオフラインモックではパスワードを再設定できません'), findsOneWidget);
    expect(find.text('パスワードを更新'), findsNothing);
  });

  test(
    'offline recovery cannot report success or change local password',
    () async {
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

      await controller.requestPasswordReset(email: 'preview@example.com');
      expect(
        container.read(authControllerProvider).passwordResetRequested,
        isFalse,
      );
      expect(
        container.read(authControllerProvider).errorMessage,
        contains('モック'),
      );

      await controller.completePasswordReset(newPassword: 'NewPassword123');
      expect(
        container.read(authControllerProvider).passwordResetCompleted,
        isFalse,
      );
      await controller.login(identifier: 'preview-user', password: 'password');
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    },
  );
}

class _ReadyRecoveryController extends AuthController {
  @override
  AuthState build() => const AuthState(isPasswordRecovery: true);
}

class _PendingSignOutController extends AuthController {
  @override
  AuthState build() => const AuthState(
    isPasswordRecovery: true,
    passwordResetCompleted: true,
    passwordResetSignOutPending: true,
  );
}
