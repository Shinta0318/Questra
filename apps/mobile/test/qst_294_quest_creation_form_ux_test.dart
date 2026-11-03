import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_field_sizes.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/quest/quest_form_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_model.dart';
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

  testWidgets('failed save retains input and retries the same Quest ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saveGate = Completer<bool>();
    late _FailingQuestController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(() {
            controller = _FailingQuestController(saveGate: saveGate);
            return controller;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuestFormScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('quest-title-field')),
      'シンガポールへ家族で行く',
    );
    await tester.tap(find.text('保存して航路を描く'));
    await tester.pump();

    expect(find.byType(QuestFormScreen), findsOneWidget);
    expect(find.text('保存中...'), findsOneWidget);
    expect(controller.attemptedIds, hasLength(1));

    saveGate.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.byType(QuestFormScreen), findsOneWidget);
    expect(find.textContaining('Questを保存できませんでした'), findsOneWidget);
    expect(controller.attemptedIds, hasLength(1));

    await tester.tap(find.text('保存して航路を描く'));
    await tester.pump();
    expect(controller.attemptedIds, hasLength(2));
    expect(controller.attemptedIds[1], controller.attemptedIds[0]);
  });

  testWidgets('failed edit remains on the form with its text preserved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = Quest(
      id: 'existing-quest',
      title: '英語を学ぶ',
      description: '旅行先で話す',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _FailingQuestController(initialQuest: original),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const QuestFormScreen(questId: 'existing-quest'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('quest-title-field')),
      '旅行先で英語を話す',
    );
    await tester.tap(find.text('変更を保存'));
    await tester.pump();

    expect(find.byType(QuestFormScreen), findsOneWidget);
    expect(find.textContaining('変更を保存できませんでした'), findsOneWidget);
    final title = tester.widget<TextFormField>(
      find.byKey(const Key('quest-title-field')),
    );
    expect(title.controller?.text, '旅行先で英語を話す');
  });
}

class _FailingQuestController extends QuestController {
  _FailingQuestController({this.initialQuest, this.saveGate});

  final Quest? initialQuest;
  final Completer<bool>? saveGate;
  final List<String> attemptedIds = [];

  @override
  List<Quest> build() => [?initialQuest];

  @override
  Future<bool> addAndWait(Quest quest) async {
    attemptedIds.add(quest.id);
    return saveGate?.future ?? false;
  }

  @override
  Future<bool> updateAndWait(Quest quest) async => false;
}
