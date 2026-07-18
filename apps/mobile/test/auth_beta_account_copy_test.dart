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

    expect(find.text('おかえりなさい'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('ログイン'), findsWidgets);
    expect(find.text('ベータアカウントを作成する'), findsOneWidget);
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

    expect(find.text('ベータアカウントを作成'), findsOneWidget);
    expect(find.text('最初のQuestを保存できるように、プロフィールを作成します。'), findsOneWidget);
    expect(find.text('表示名'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('アカウントを作成'), findsOneWidget);
    expect(find.text('Create your profile'), findsNothing);
    expect(find.text('Signup'), findsNothing);
  });
}
