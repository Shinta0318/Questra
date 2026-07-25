import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/forgot_password_screen.dart';
import 'package:questra/features/auth/reset_password_screen.dart';

void main() {
  testWidgets('Forgot password asks for the linked email address', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ForgotPasswordScreen()),
      ),
    );

    expect(find.text('航路を取り戻す'), findsOneWidget);
    expect(find.text('登録メールアドレス'), findsOneWidget);
    expect(find.text('再設定メールを送る'), findsOneWidget);
  });

  testWidgets('Reset password requires a new password twice', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ResetPasswordScreen()),
      ),
    );

    expect(find.text('新しい鍵を決める'), findsOneWidget);
    expect(find.text('新しいパスワード'), findsOneWidget);
    expect(find.text('新しいパスワード（確認）'), findsOneWidget);
    expect(find.text('パスワードを更新'), findsOneWidget);
  });
}
