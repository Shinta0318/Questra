import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/reset_password_screen.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/signup_screen.dart';

void main() {
  testWidgets('login does not mark untouched password as invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'a');
    await tester.pump();
    expect(find.textContaining('ログインIDは3〜'), findsOneWidget);
    expect(find.text('パスワードを入力してください。'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).first,
      'captain@example.com',
    );
    await tester.pump();

    expect(find.textContaining('ログインIDは3〜'), findsNothing);
    expect(find.text('パスワードを入力してください。'), findsNothing);
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('パスワードを入力してください。'), findsOneWidget);
  });

  testWidgets('signup waits to validate untouched account fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const SignupScreen()),
      ),
    );
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

    await tester.enterText(find.byType(TextFormField).first, 'テストキャプテン');
    await tester.pump();
    expect(find.text('ログインIDを入力してください。'), findsNothing);
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('ログインIDを入力してください。'), findsOneWidget);
  });

  testWidgets('reset does not mark untouched confirmation as invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authEmailAvailableProvider.overrideWithValue(true),
          authControllerProvider.overrideWith(_ReadyRecoveryController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ResetPasswordScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'SafePass123');
    await tester.pump();

    expect(find.text('確認用パスワードを入力してください。'), findsNothing);
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('確認用パスワードを入力してください。'), findsOneWidget);
  });
}

class _ReadyRecoveryController extends AuthController {
  @override
  AuthState build() => const AuthState(isPasswordRecovery: true);
}
