import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_field_sizes.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/quest/quest_form_screen.dart';
import 'package:questra/widgets/questra_card.dart';

void main() {
  Future<void> pumpForm(WidgetTester tester, {required Size viewport}) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuestFormScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('long Quest inputs use readable one-column text areas', (
    tester,
  ) async {
    await pumpForm(tester, viewport: const Size(1280, 900));

    TextField textField(Key key) => tester.widget<TextField>(
      find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
    );
    final title = textField(const Key('quest-title-field'));
    final motivation = textField(const Key('quest-motivation-field'));
    final success = textField(const Key('quest-success-condition-field'));

    expect(title.minLines, 1);
    expect(title.maxLines, 2);
    expect(motivation.minLines, 3);
    expect(motivation.maxLines, 6);
    expect(motivation.maxLength, 280);
    expect(success.minLines, 3);
    expect(success.maxLines, 6);
    expect(success.maxLength, 280);
    expect(find.text('難しさ'), findsNothing);
    expect(find.text('Arcによる航路分析'), findsOneWidget);
    expect(find.text('あなたが決める'), findsNWidgets(4));
  });

  testWidgets('desktop form is centered and width-bounded', (tester) async {
    await pumpForm(tester, viewport: const Size(1440, 1000));

    final size = tester.getSize(find.byType(QuestraCard).first);
    expect(size.width, lessThanOrEqualTo(AppFieldSizes.questFormMaxWidth));
  });

  testWidgets('mobile form accepts Japanese multiline IME text', (
    tester,
  ) async {
    await pumpForm(tester, viewport: const Size(390, 844));
    final field = find.byKey(const Key('quest-motivation-field'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '家族と新しい景色を見たい。\n大切な思い出を残したい。');
    await tester.pump();

    final widget = tester.widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    );
    expect(widget.controller?.text, contains('家族と新しい景色'));
    expect(widget.controller?.text, contains('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('target date is requested as year and month', (tester) async {
    await pumpForm(tester, viewport: const Size(390, 844));
    final target = find.byKey(const Key('quest-target-month-button'));
    await tester.ensureVisible(target);
    await tester.pump();

    expect(target, findsOneWidget);
    expect(find.text('YYYY / MM を選ぶ'), findsOneWidget);
  });
}
