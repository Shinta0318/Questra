import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_evaluation.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_screen.dart';

void main() {
  testWidgets('Quest一覧は重複Heroと未評価の0値を表示しない', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quest = _quest(targetDate: DateTime(2027, 9, 1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController([quest]),
          ),
        ],
        child: const MaterialApp(home: QuestScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Quest一覧'), findsNothing);
    expect(find.text('Questの現在地'), findsNothing);
    expect(find.text('あなたのQuest'), findsOneWidget);
    expect(find.text('Missionを準備中'), findsOneWidget);
    expect(find.text('Mission 0/0'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('ふつう'), findsNothing);
    expect(find.text('冒険'), findsNothing);
    expect(find.text('目標 2027年9月'), findsOneWidget);
  });

  testWidgets('AI評価があるQuestだけ難易度の由来を表示する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quest = _quest(
      evaluation: QuestEvaluation(
        difficultyScore: 4,
        estimatedDurationDays: 90,
        estimatedMissionCount: 8,
        version: 'test-v1',
        evaluatedAt: DateTime(2026, 9, 6),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController([quest]),
          ),
        ],
        child: const MaterialApp(home: QuestScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('難易度 ★★★★☆'), findsOneWidget);
    expect(find.text('ふつう'), findsNothing);
  });

  testWidgets('詳細Headerは100文字と2倍文字でも編集と年月を保つ', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final title = List.filled(10, '自分らしい働き方を見つける').join();
    final quest = _quest(title: title);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController([quest]),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: QuestDetailScreen(questId: quest.id),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final header = find.byKey(const ValueKey('quest-compact-header'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text(title)),
      findsOneWidget,
    );
    expect(find.text('目標年月 未設定'), findsOneWidget);
    expect(find.byTooltip('Questを編集'), findsOneWidget);
    expect(find.text('Questを編集'), findsNothing);
    expect(find.textContaining('Arc評価'), findsNothing);
  });

  testWidgets('通常のQuest詳細は390px初期画面内に航路入口を示す', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final quest = _quest(targetDate: DateTime(2027, 9, 1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(
            () => _StaticQuestController([quest]),
          ),
        ],
        child: MaterialApp(home: QuestDetailScreen(questId: quest.id)),
      ),
    );
    await tester.pump();

    final journeyEntry = find.text('航路を進める');
    expect(journeyEntry, findsOneWidget);
    expect(tester.getBottomLeft(journeyEntry).dy, lessThan(844));
    expect(tester.takeException(), isNull);
  });
}

Quest _quest({
  String title = 'シンガポール旅行を実現する',
  DateTime? targetDate,
  QuestEvaluation? evaluation,
}) {
  return Quest(
    title: title,
    description: '希望する体験と条件を整理して、実行できる航路をつくる。',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
    category: '冒険',
    targetDate: targetDate,
    evaluation: evaluation,
  );
}

class _StaticQuestController extends QuestController {
  _StaticQuestController(this.quests);

  final List<Quest> quests;

  @override
  List<Quest> build() => quests;
}
