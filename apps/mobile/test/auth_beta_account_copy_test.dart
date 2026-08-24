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
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignupScreen())),
    );

    expect(find.text('安心して始めるために'), findsOneWidget);
    expect(find.text('最初のQuestを灯そう'), findsNothing);
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
