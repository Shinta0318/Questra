import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:questra/features/arc/arc_screen.dart';
import 'package:questra/features/arc/arc_chat_service.dart';
import 'package:questra/features/arc/arc_quest_creation_context.dart';
import 'package:questra/features/arc/arc_quest_clarification_session.dart';
import 'package:questra/features/arc/arc_quick_action.dart';
import 'package:questra/features/quest/quest_clarification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ArcChatMessage message(String text, {bool fromArc = false}) =>
      ArcChatMessage(text: text, fromArc: fromArc, createdAt: DateTime(2026));

  test('keeps the original wish and answered conditions from chat', () {
    final suggestion = inferArcQuestSuggestion('シンガポールに行きたい')!;
    final session = ArcQuestClarificationSession(
      suggestion: suggestion,
      questions: QuestClarificationService.resolve(
        input: suggestion.sourceInput,
        category: '旅行',
        targetDate: null,
      ),
      answers: const {
        QuestClarificationType.deadline: '2028年10月',
        QuestClarificationType.party: '一人で',
        QuestClarificationType.budget: '20万円',
      },
    );
    final result = ArcQuestCreationContext.fromConversation(
      messages: [message('シンガポールに行きたい'), message('一人で')],
      suggestions: [session.resolvedSuggestion],
    );
    expect(result.wish, 'シンガポールに行きたい');
    expect(result.suggestion!.title, 'シンガポールへ行く');
    expect(result.suggestion!.description, contains('2028年10月'));
    expect(result.suggestion!.description, contains('20万円'));
  });

  test('falls back to a real wish, not a command or Arc reply', () {
    final result = ArcQuestCreationContext.fromConversation(
      messages: [
        message('シンガポールに行きたい'),
        message('一人で'),
        message(ArcQuickAction.fromLabel('Questを作る').prompt),
        message('英語を話せるようになりたい', fromArc: true),
      ],
      suggestions: const [],
    );
    expect(result.wish, 'シンガポールに行きたい');
    expect(result.suggestion, isNull); // Resolve safely before confirming.
  });

  test('does not manufacture a wish for an empty conversation', () {
    final result = ArcQuestCreationContext.fromConversation(
      messages: [message(ArcQuickAction.fromLabel('やりたいことを相談').prompt)],
      suggestions: const [],
    );
    expect(result.wish, isEmpty);
  });

  testWidgets('chat wish opens as a summary and remains editable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ArcScreen())),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('arc-chat-input')),
      '2028年10月までにシンガポールに行きたい',
    );
    await tester.tap(find.byTooltip('メッセージを送信'));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final create = find.widgetWithText(FilledButton, 'Questとして始める');
    await tester.ensureVisible(create.first);
    await tester.tap(create.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Arcに伝えたこと'), findsOneWidget);
    expect(find.text('Arcに相談すること'), findsNothing);
    await tester.tap(find.byTooltip('相談内容を編集'));
    await tester.pump();
    expect(find.text('Arcに相談すること'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == '2028年10月までにシンガポールに行きたい'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test('operation prompts cannot become local Quest suggestions', () {
    for (final label in [
      'やりたいことを相談',
      'Questを作る',
      '今日の一歩を決める',
      '計画を見直す',
      '情報を調べる',
      'Questとして始める',
      '相談として続ける',
    ]) {
      expect(
        inferArcQuestSuggestion(ArcQuickAction.fromLabel(label).prompt),
        isNull,
      );
    }
    expect(inferArcQuestSuggestion('シンガポールに行きたい'), isNotNull);
  });
}
