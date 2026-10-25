import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_error_notice.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/login_screen.dart';

void main() {
  const message =
      'ログインを確認できませんでした。通信状態を確認してから、もう一度お試しください。解決しない場合はパスワードを再設定できます。';

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('auth error stays readable at 320px and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AuthErrorNotice(message: message),
            ),
          ),
        ),
      );

      final notice = find.byType(AuthErrorNotice);
      final container = tester.widget<Container>(
        find.descendant(of: notice, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final background = decoration.color!;
      final text = tester.widget<Text>(find.text(message));
      final icon = tester.widget<Icon>(
        find.descendant(of: notice, matching: find.byType(Icon)),
      );
      final semantics = tester.widget<Semantics>(
        find.descendant(of: notice, matching: find.byType(Semantics)).first,
      );

      expect(
        _contrast(text.style!.color!, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(icon.color!, background), greaterThanOrEqualTo(3));
      expect(semantics.properties.liveRegion, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login failure uses the shared notice', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_FailedLogin.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.ensureVisible(find.byType(AuthErrorNotice));
    await tester.pumpAndSettle();

    expect(find.text('ログインIDまたはパスワードを確認してください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FailedLogin extends AuthController {
  @override
  AuthState build() => const AuthState(
    errorMessage: 'ログインIDまたはパスワードを確認してください。',
    errorContext: AuthErrorContext.login,
  );
}

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
