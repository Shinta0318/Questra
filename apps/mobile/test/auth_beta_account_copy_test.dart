import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/signup_screen.dart';

void main() {
  testWidgets('Login screen uses beta-ready Japanese account copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('航海を続けよう'), findsOneWidget);
    expect(find.text('ログインIDまたはメールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('ログイン'), findsWidgets);
    expect(find.text('新しく航海を始める'), findsOneWidget);
    expect(find.text('パスワードを忘れた方'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Login'), findsNothing);
    expect(find.text('Create an account'), findsNothing);
  });

  testWidgets('Signup screen explains first Quest persistence setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );

    expect(find.text('最初のQuestを灯そう'), findsOneWidget);
    expect(find.text('Arcからの呼び名'), findsOneWidget);
    expect(find.text('ログインID'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('航海を始める'), findsOneWidget);
    expect(find.text('Create your profile'), findsNothing);
    expect(find.text('Signup'), findsNothing);
  });
}
