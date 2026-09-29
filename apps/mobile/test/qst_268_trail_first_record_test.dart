import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/features/trail/trail_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('空のTrail画面は初期表示内に作成CTAを一つだけ表示する', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TrailScreen())),
    );
    await tester.pump();

    final primaryAction = find.byKey(const ValueKey('trail-primary-create'));
    expect(primaryAction, findsOneWidget);
    expect(find.text('最初のTrailを残す'), findsOneWidget);
    expect(tester.getTopLeft(primaryAction).dy, lessThan(500));
  });

  testWidgets('短い記録だけで保存し、単一の時系列へすぐ反映される', (tester) async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_TrailQuestController.new),
        missionControllerProvider.overrideWith(_TrailMissionController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _selectParent(tester);

    final fields = find.byType(TextFormField);
    expect(fields, findsOneWidget);
    await tester.enterText(fields.at(0), '今日の一歩を残した。小さく始められたので、明日も続けたい。');
    await tester.ensureVisible(find.text('Trailを保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(BottomSheet), findsNothing);
    expect(container.read(trailControllerProvider).single.title, '今日の一歩を残した');
    await tester.scrollUntilVisible(
      find.text('今日の一歩を残した'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('今日の一歩を残した'), findsOneWidget);
    expect(find.text('Trail 1件'), findsOneWidget);
    expect(find.text('Trailを残す'), findsOneWidget);
  });

  testWidgets('保存失敗時は入力を保持して再試行できる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailControllerProvider.overrideWith(_FailingTrailController.new),
          questControllerProvider.overrideWith(_TrailQuestController.new),
          missionControllerProvider.overrideWith(_TrailMissionController.new),
        ],
        child: const MaterialApp(home: TrailScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _selectParent(tester);
    final fields = find.byType(TextFormField);
    expect(fields, findsOneWidget);
    await tester.enterText(fields.at(0), '消えない入力。失敗時も保持する。');
    await tester.ensureVisible(find.text('Trailを保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('再試行できます'), findsOneWidget);
    expect(find.text('Trailを保存'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, '消えない入力。失敗時も保持する。'),
      findsOneWidget,
    );
  });
}

Future<void> _selectParent(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('trail-quest-selector')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('シンガポールへ行く').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(
    find.byKey(const ValueKey('trail-mission-selector-quest-1')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('旅行日程を決める').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _TrailQuestController extends QuestController {
  @override
  List<Quest> build() => [
    Quest(
      id: 'quest-1',
      title: 'シンガポールへ行く',
      description: '家族旅行を実現する',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    ),
  ];
}

class _TrailMissionController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-1',
      questId: 'quest-1',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '候補日を比較する',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

class _FailingTrailController extends TrailController {
  @override
  List<Trail> build() => const [];

  @override
  Future<bool> addManualTrailAndWait({
    required String title,
    required String summary,
    required String content,
    String? trailId,
    TrailParentContext? parent,
  }) async => false;
}
