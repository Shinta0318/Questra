import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/validation/input_validators.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/trust/legal_policy.dart';

void main() {
  test(
    'common domain typo is suggested but a different domain is accepted',
    () {
      expect(
        InputValidators.suggestedEmailCorrection('traveler@gmai.com'),
        'traveler@gmail.com',
      );
      expect(
        InputValidators.suggestedEmailCorrection('traveler@custom.example'),
        isNull,
      );
      expect(InputValidators.suggestedEmailCorrection('not-an-email'), isNull);
    },
  );

  testWidgets('signup confirms a suspicious email before sending it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_SignupProbe.new)],
    );
    addTearDown(container.dispose);
    final probe =
        container.read(authControllerProvider.notifier) as _SignupProbe;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
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

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Traveler');
    await tester.enterText(fields.at(1), 'traveler');
    await tester.enterText(fields.at(2), 'traveler@gmai.com');
    await tester.enterText(fields.at(3), 'Password123');
    await tester.pump();
    expect(find.text('@gmail.com に修正する'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, 'アカウントを作成');
    await tester.ensureVisible(submit);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('メールアドレスを確認'), findsOneWidget);
    expect(probe.calls, 0);

    await tester.tap(find.text('修正する'));
    await tester.pumpAndSettle();
    expect(probe.calls, 0);
    await tester.ensureVisible(find.text('@gmail.com に修正する'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@gmail.com に修正する'));
    await tester.pump();
    expect(find.text('@gmail.com に修正する'), findsNothing);

    await tester.ensureVisible(submit);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(probe.calls, 1);
    expect(probe.lastEmail, 'traveler@gmail.com');
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup keeps the original address only after explicit choice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_SignupProbe.new)],
    );
    addTearDown(container.dispose);
    final probe =
        container.read(authControllerProvider.notifier) as _SignupProbe;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SignupScreen()),
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
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Traveler');
    await tester.enterText(fields.at(1), 'traveler');
    await tester.enterText(fields.at(2), 'traveler@gmai.com');
    await tester.enterText(fields.at(3), 'Password123');

    final submit = find.widgetWithText(FilledButton, 'アカウントを作成');
    await tester.ensureVisible(submit);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(probe.calls, 0);
    await tester.tap(find.text('このまま登録'));
    await tester.pumpAndSettle();
    expect(probe.calls, 1);
    expect(probe.lastEmail, 'traveler@gmai.com');
    expect(tester.takeException(), isNull);
  });
}

class _SignupProbe extends AuthController {
  int calls = 0;
  String? lastEmail;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String nickname,
    String? loginId,
    required LegalAcceptance legalAcceptance,
  }) async {
    calls++;
    lastEmail = email;
  }
}
