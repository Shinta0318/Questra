import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/auth_error_notice.dart';
import 'package:questra/features/auth/auth_journey_scaffold.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/login_screen.dart';

void main() {
  testWidgets('compact mobile form begins below the Arc wordmark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AuthJourneyScaffold(
          eyebrow: 'ログイン',
          message: 'Arcと進めよう。',
          mobileFormHeader: true,
          child: SizedBox(height: 100, child: Text('フォーム')),
        ),
      ),
    );

    expect(tester.getRect(find.text('ログイン')).top, lessThan(150));
    expect(tester.getRect(find.text('フォーム')).top, lessThan(220));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed login keeps the error and retry action in 390px view', (
    tester,
  ) async {
    await _showFailedLogin(tester, const Size(390, 844));

    final error = find.byType(AuthErrorNotice);
    final retry = find.widgetWithText(FilledButton, 'ログイン');
    expect(tester.getRect(error).bottom, lessThan(tester.getRect(retry).top));
    expect(tester.getRect(retry).bottom, lessThanOrEqualTo(844 - 16));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'Arc',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed login remains scrollable at 320px and 200% text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _showFailedLogin(tester, const Size(320, 640));

    final retry = find.widgetWithText(FilledButton, 'ログイン');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    expect(tester.getRect(retry).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keeps the wide Arc panel', (tester) async {
    await _showFailedLogin(tester, const Size(900, 700));

    final arcImage = find.byType(Image).first;
    expect(tester.getRect(arcImage).width, greaterThan(400));
    expect(tester.getRect(arcImage).height, 700);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _showFailedLogin(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pump();
}

class _FailedLogin extends AuthController {
  @override
  AuthState build() => const AuthState(
    errorMessage: 'ログインIDまたはパスワードを確認してください。10回連続で失敗すると30分間ログインできません。',
    errorContext: AuthErrorContext.login,
  );
}
