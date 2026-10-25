import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/auth/signup_screen.dart';

void main() {
  testWidgets('signup account form shows the email field at 390px', (
    tester,
  ) async {
    await _showAccountForm(tester, const Size(390, 844));

    final emailField = find.byType(TextFormField).at(2);
    expect(tester.getRect(emailField).bottom, lessThanOrEqualTo(844));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == 'Arc',
      ),
      findsOneWidget,
    );
  });

  testWidgets('signup account form does not overflow at 320px', (
    tester,
  ) async {
    await _showAccountForm(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });
}

Future<void> _showAccountForm(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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

  final scrollable = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    ).first,
  );
  scrollable.position.jumpTo(0);
  await tester.pumpAndSettle();
}
