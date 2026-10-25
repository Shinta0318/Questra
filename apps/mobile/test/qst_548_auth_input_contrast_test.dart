import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/core/theme/questra_surface_palette.dart';
import 'package:questra/features/auth/confirm_email_help_screen.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_email_availability.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/auth/forgot_password_screen.dart';
import 'package:questra/features/auth/login_screen.dart';
import 'package:questra/features/auth/reset_password_screen.dart';
import 'package:questra/features/auth/signup_screen.dart';
import 'package:questra/features/quest/quest_form_screen.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('default app fields show Japanese text on a light surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TextField()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'シンガポールへ行きたい');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final background =
        field.decoration?.fillColor ??
        AppTheme.light.inputDecorationTheme.fillColor;
    expect(background, isNotNull);
    expect(find.text('シンガポールへ行きたい'), findsOneWidget);
    expect(
      _contrast(editable.style.color!, background!),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('default app fields remain readable in the dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: TextField()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'シンガポールへ行きたい');
    await tester.pump();
    _expectRenderedFieldContrast(tester, find.byType(Scaffold));
  });

  testWidgets('dark surface fields use a readable dark fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: QuestraSurfaceScope(
            palette: QuestraSurfacePalette.dark,
            child: TextField(),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'シンガポールへ行きたい');
    await tester.pump();
    _expectRenderedFieldContrast(tester, find.byType(Scaffold));
  });

  for (final (name, screen, count) in [
    ('login', const LoginScreen(), 2),
    ('forgot password', const ForgotPasswordScreen(), 1),
    ('reset password', const ResetPasswordScreen(), 2),
  ]) {
    testWidgets('$name inputs remain readable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authEmailAvailableProvider.overrideWithValue(true),
            if (name == 'reset password')
              authControllerProvider.overrideWith(_ReadyRecoveryController.new),
          ],
          child: MaterialApp(theme: AppTheme.light, home: screen),
        ),
      );
      await tester.pump();
      _expectReadableInputs(tester, count);
    });
  }

  testWidgets(
    'confirmation help input remains readable when mail is available',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            confirmationEmailAvailableProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ConfirmEmailHelpScreen(),
          ),
        ),
      );
      await tester.pump();
      _expectReadableInputs(tester, 1);
    },
  );

  testWidgets('signup inputs remain readable after eligibility consent', (
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

    _expectReadableInputs(tester, 4);
  });

  testWidgets('Quest form keeps Japanese input readable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuestFormScreen(),
        ),
      ),
    );
    await tester.pump();

    final title = find.byKey(const Key('quest-title-field'));
    await tester.enterText(title, 'シンガポールへ行く');
    await tester.pump();
    _expectRenderedFieldContrast(tester, title);

    final motivation = find.byKey(const Key('quest-motivation-field'));
    await tester.ensureVisible(motivation);
    await tester.enterText(motivation, '家族と新しい景色を見たい。');
    await tester.pump();
    _expectRenderedFieldContrast(tester, motivation);
  });

  testWidgets('Trail composer keeps Japanese input readable', (tester) async {
    const parent = TrailParentContext(
      questId: 'quest-1',
      questTitle: 'シンガポールへ行く',
      missionId: 'mission-1',
      missionTitle: '渡航準備を整える',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TrailScreen(initialParent: parent, openComposer: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final note = find.byKey(const ValueKey('trail-quick-note'));
    await tester.enterText(note, '今日、渡航準備を一歩進めた。');
    await tester.pump();
    _expectRenderedFieldContrast(tester, note);
  });
}

class _ReadyRecoveryController extends AuthController {
  @override
  AuthState build() => const AuthState(isPasswordRecovery: true);
}

void _expectRenderedFieldContrast(WidgetTester tester, Finder fieldFinder) {
  final textFieldFinder = find.descendant(
    of: fieldFinder,
    matching: find.byType(TextField),
  );
  final field = tester.widget<TextField>(textFieldFinder);
  final editable = tester.widget<EditableText>(
    find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
  );
  final theme = Theme.of(tester.element(textFieldFinder));
  final background =
      field.decoration?.fillColor ?? theme.inputDecorationTheme.fillColor;
  expect(background, isNotNull);
  expect(editable.style.color, isNotNull);
  expect(
    _contrast(editable.style.color!, background!),
    greaterThanOrEqualTo(4.5),
  );
}

void _expectReadableInputs(WidgetTester tester, int expectedCount) {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  expect(fields, hasLength(expectedCount));
  for (final field in fields) {
    final textColor = field.style?.color;
    final backgroundColor = field.decoration?.fillColor;
    expect(textColor, isNotNull);
    expect(backgroundColor, isNotNull);
    expect(field.decoration?.filled, isTrue);

    expect(_contrast(textColor!, backgroundColor!), greaterThanOrEqualTo(4.5));
  }
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
