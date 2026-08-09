import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_detail_screen.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_detail_screen.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/trail/trail_controller.dart';
import 'package:questra/features/trail/trail_screen.dart';

void registerQst269CoreJourneyTests() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets('TaskからMission達成とTrail記録まで中心導線を完遂できる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        missionControllerProvider.overrideWith(
          Qst269JourneyMissionController.new,
        ),
        taskControllerProvider.overrideWith(Qst269JourneyTaskController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TaskDetailScreen(taskId: 'task-e2e'),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('Taskを開始'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Taskを開始'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(taskControllerProvider).single.status,
      TaskStatus.inProgress,
    );

    await tester.ensureVisible(find.text('Taskを完了'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Taskを完了'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(taskControllerProvider).single.status,
      TaskStatus.completed,
    );
    expect(
      container.read(missionControllerProvider).single.progressPercent,
      100,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MissionDetailScreen(missionId: 'mission-e2e'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('必須Task 1 / 1 完了'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('成果を確認してMission達成'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('成果を確認してMission達成'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(missionControllerProvider).single.successConfirmedAt,
      isNotNull,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const TrailScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('trail-primary-create')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Missionを達成した日');
    await tester.enterText(fields.at(1), '成果を確認して次へ進めた');
    await tester.enterText(fields.at(2), 'Taskを終え、Missionの成果を確認した。');
    await tester.tap(find.text('Trailを保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(trailControllerProvider), hasLength(1));
    expect(
      container.read(trailControllerProvider).single.title,
      'Missionを達成した日',
    );
  });

  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('Mission詳細は幅${width.toInt()}で読み上げ順と操作領域を保つ', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            missionControllerProvider.overrideWith(
              Qst269JourneyMissionController.new,
            ),
            taskControllerProvider.overrideWith(
              Qst269CompletedTaskController.new,
            ),
          ],
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: const MissionDetailScreen(missionId: 'mission-e2e'),
            ),
          ),
        ),
      );
      await tester.pump();

      final questLabel = tester.getTopLeft(find.text('QUEST  小さな航路を完成させる'));
      final missionLabel = tester.getTopLeft(find.text('MISSION'));
      final missionTitle = tester.getTopLeft(find.text('最初の成果を形にする'));
      expect(questLabel.dy, lessThan(missionLabel.dy));
      expect(missionLabel.dy, lessThan(missionTitle.dy));

      await tester.scrollUntilVisible(
        find.text('成果を確認してMission達成'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final confirm = find.widgetWithText(FilledButton, '成果を確認してMission達成');
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
      expect(tester.getSemantics(confirm).label, contains('成果を確認してMission達成'));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

class Qst269JourneyMissionController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-e2e',
      questId: 'quest-e2e',
      questTitle: '小さな航路を完成させる',
      title: '最初の成果を形にする',
      description: '一つの成果を確認できる状態にする',
      objective: '確認できる成果を一つ残す',
      successCondition: '必要なTaskが完了し、成果を確認できる',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

class Qst269JourneyTaskController extends TaskController {
  @override
  List<QuestraTask> build() => [
    QuestraTask(
      id: 'task-e2e',
      questId: 'quest-e2e',
      missionId: 'mission-e2e',
      questTitle: '小さな航路を完成させる',
      missionTitle: '最初の成果を形にする',
      title: '確認用の成果を作る',
      action: '確認用の成果を一つ作成する',
      purpose: 'Missionの達成条件を満たすため',
      doneCondition: '成果が一つ保存されている',
      expectedOutput: '確認できる成果',
      estimatedEffortMinutes: 15,
      status: TaskStatus.pending,
    ),
  ];
}

class Qst269CompletedTaskController extends TaskController {
  @override
  List<QuestraTask> build() => [
    QuestraTask(
      id: 'task-e2e',
      questId: 'quest-e2e',
      missionId: 'mission-e2e',
      questTitle: '小さな航路を完成させる',
      missionTitle: '最初の成果を形にする',
      title: '確認用の成果を作る',
      action: '確認用の成果を一つ作成する',
      purpose: 'Missionの達成条件を満たすため',
      doneCondition: '成果が一つ保存されている',
      expectedOutput: '確認できる成果',
      status: TaskStatus.completed,
      completedAt: DateTime(2026, 8, 8),
    ),
  ];
}
