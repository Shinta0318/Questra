import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/signup_screen.dart';

void main() {
  testWidgets('Login screen uses beta-ready Japanese account copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('おかえりなさい'), findsNothing);
    expect(find.text('ログインIDまたはメールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('ログイン'), findsWidgets);
    expect(find.text('新規登録'), findsWidgets);
    expect(find.text('パスワードを忘れた方'), findsNothing);
    expect(find.text('確認メールが届かない方'), findsNothing);
    expect(find.text('モックを開く'), findsOneWidget);
    expect(find.text('プレビューで作成したアカウントでログイン'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Login'), findsNothing);
    expect(find.text('Create an account'), findsNothing);
  });

  testWidgets('connected login retains email recovery links', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authEmailAvailableProvider.overrideWithValue(true)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('確認メールが届かない方'), findsOneWidget);
    expect(find.text('パスワードを忘れた方'), findsOneWidget);
    expect(find.text('モックを開く'), findsNothing);
  });

  testWidgets('Signup screen explains first Quest persistence setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );

    expect(find.text('はじめに確認すること'), findsNothing);
    expect(find.text('アカウントを作成'), findsNothing);
    expect(find.text('Arcからの呼び名'), findsNothing);

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

    expect(find.text('アカウントを作成'), findsWidgets);
    expect(find.text('Arcからの呼び名'), findsOneWidget);
    expect(find.text('ログインID'), findsOneWidget);
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('新規登録'), findsWidgets);
    expect(find.text('Create your profile'), findsNothing);
    expect(find.text('Signup'), findsNothing);
  });
}
