import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_detail_screen.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest_journey/quest_journey_contract.dart';

final _quest = Quest(
  id: 'quest-dialog',
  title: '家族でシンガポール旅行を実現する',
  description: '食事と観光を楽しむ',
  difficulty: QuestDifficulty.normal,
  status: QuestStatus.active,
  visibility: QuestVisibility.private,
);

Mission _mission() => Mission(
  id: 'mission-dialog',
  questId: _quest.id,
  questTitle: _quest.title,
  title: '航空券を確保する',
  description: '希望日程の予約を確定する',
  objective: '希望日程の予約を確定する',
  successCondition: '予約番号を保存して確認できる',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.todo,
  targetDate: DateTime(2025, 1, 1),
);

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('create and close survives 10 rebuilds at width $width', (
      tester,
    ) async {
      final container = await _mount(tester, width: width);
      for (var i = 0; i < 10; i++) {
        _controller(container).clearForTest();
        await _flush(tester);
        await _openCreate(tester);
        await tester.enterText(find.byType(TextFormField).at(0), '航空券を確保する');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          '予約番号を保存して確認する',
        );
        final button = find.widgetWithText(FilledButton, '追加');
        await tester.ensureVisible(button);
        final submitPosition = tester.getCenter(button);
        await tester.tapAt(submitPosition);
        // A second event before the closing route is rebuilt must not add twice.
        await tester.tapAt(submitPosition);
        await _flush(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(container.read(missionControllerProvider), hasLength(1));
        expect(
          container.read(missionControllerProvider).single.questId,
          _quest.id,
        );
        expect(tester.takeException(), isNull);
      }
      await _dispose(tester, container);
    });
  }

  for (final dismiss in ['cancel', 'escape', 'barrier']) {
    testWidgets('$dismiss discards input without disposed-controller error', (
      tester,
    ) async {
      final container = await _mount(tester);
      await _openCreate(tester);
      await tester.enterText(find.byType(TextFormField).first, '未保存の航空券');
      switch (dismiss) {
        case 'cancel':
          await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
        case 'escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
      }
      await _flush(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(missionControllerProvider), isEmpty);
      expect(tester.takeException(), isNull);
      await _dispose(tester, container);
    });
  }

  testWidgets('empty and Quest-identical Mission titles stay in the form', (
    tester,
  ) async {
    final container = await _mount(tester);
    await _openCreate(tester);
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await _flush(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, _quest.title);
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await _flush(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(container.read(missionControllerProvider), isEmpty);
    await _dispose(tester, container);
  });

  testWidgets('parent rebuild and duplicate title keep the open form intact', (
    tester,
  ) async {
    final container = await _mount(tester);
    await _openCreate(tester);
    await tester.enterText(find.byType(TextFormField).first, '航空券を確保する');
    _controller(container).seedForTest();
    await _flush(tester);
    await tester.tap(find.widgetWithText(FilledButton, '追加'));
    await _flush(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(container.read(missionControllerProvider), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
    await _flush(tester);
    expect(
      container.read(missionControllerProvider).single.id,
      'mission-dialog',
    );
    expect(tester.takeException(), isNull);
    await _dispose(tester, container);
  });

  // Editing is exposed by the legacy Mission card menu. Run this suite with
  // --dart-define=QUEST_JOURNEY_WORKSPACE=false to exercise that entry point.
  if (!const bool.fromEnvironment(
    'QUEST_JOURNEY_WORKSPACE',
    defaultValue: true,
  )) {
    testWidgets(
      'edit keeps input on mutation failure and closes safely on retry',
      (tester) async {
        final container = await _mount(tester, seed: true);
        final menu = find.byTooltip('Missionのその他の操作');
        await tester.scrollUntilVisible(
          menu,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(menu);
        await _flush(tester);
        await tester.tap(find.text('Missionを編集'));
        await _flush(tester);
        await tester.enterText(find.byType(TextFormField).first, '航空券の予約を確定する');
        final controller = _controller(container);
        controller.failUpdate = true;
        final save = find.widgetWithText(FilledButton, '保存');
        await tester.tap(save);
        await _flush(tester);
        expect(find.textContaining('Missionを更新できませんでした'), findsOneWidget);
        expect(find.text('航空券の予約を確定する'), findsOneWidget);
        expect(
          container.read(missionControllerProvider).single.title,
          '航空券を確保する',
        );
        controller.failUpdate = false;
        final savePosition = tester.getCenter(save);
        await tester.tapAt(savePosition);
        await tester.tapAt(savePosition);
        await _flush(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          container.read(missionControllerProvider).single.title,
          '航空券の予約を確定する',
        );
        expect(controller.successfulUpdates, 1);
        expect(tester.takeException(), isNull);
        await _dispose(tester, container);
      },
    );

    testWidgets('editing a past deadline can open and cancel the date picker', (
      tester,
    ) async {
      final container = await _mount(tester, seed: true);
      final menu = find.byTooltip('Missionのその他の操作');
      await tester.scrollUntilVisible(
        menu,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(menu);
      await _flush(tester);
      await tester.tap(find.text('Missionを編集'));
      await _flush(tester);
      await tester.ensureVisible(find.text('期限').last);
      await tester.tap(find.text('期限').last);
      await _flush(tester);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _flush(tester);
      await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
      await _flush(tester);
      expect(
        container.read(missionControllerProvider).single.targetDate,
        DateTime(2025, 1, 1),
      );
      expect(tester.takeException(), isNull);
      await _dispose(tester, container);
    });
  }

  testWidgets(
    'removing the host with an open dialog releases controllers safely',
    (tester) async {
      final container = await _mount(tester);
      await _openCreate(tester);
      await tester.enterText(find.byType(TextFormField).first, '航空券を確保する');
      await _dispose(tester, container);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  double width = 390,
  bool seed = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      questControllerProvider.overrideWith(_QuestController.new),
      missionControllerProvider.overrideWith(_MissionController.new),
    ],
  );
  if (seed) _controller(container).seedForTest();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: QuestDetailScreen(
          questId: _quest.id,
          initialJourneyMode: QuestJourneyMode.plan,
        ),
      ),
    ),
  );
  await _flush(tester);
  return container;
}

Future<void> _openCreate(WidgetTester tester) async {
  final create = find.text('Missionを追加');
  await tester.scrollUntilVisible(
    create,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await _flush(tester);
  await tester.ensureVisible(create);
  await _flush(tester);
  await tester.tap(create);
  await _flush(tester);
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _dispose(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _flush(tester);
  container.dispose();
}

_MissionController _controller(ProviderContainer container) =>
    container.read(missionControllerProvider.notifier) as _MissionController;

class _QuestController extends QuestController {
  @override
  List<Quest> build() => [_quest];
}

class _MissionController extends MissionController {
  bool failUpdate = false;
  int successfulUpdates = 0;
  @override
  List<Mission> build() => [];
  void clearForTest() => state = [];
  void seedForTest() => state = [_mission()];
  @override
  void updateMission(Mission mission) {
    if (failUpdate) throw StateError('test mutation failure');
    successfulUpdates++;
    super.updateMission(mission);
  }
}
