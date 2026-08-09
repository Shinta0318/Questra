import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/home/home_today_task_journey.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_load_state.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  const service = HomeTodayTaskJourneyService();
  final now = DateTime(2026, 8, 8, 12);

  test('取得状態と今日の完了状態を明示的に分ける', () {
    expect(
      service
          .resolve(
            tasks: const [],
            loadState: const TaskLoadState(status: TaskLoadStatus.loading),
            now: now,
          )
          .status,
      HomeTodayTaskStatus.loading,
    );
    expect(
      service
          .resolve(
            tasks: const [],
            loadState: const TaskLoadState(status: TaskLoadStatus.failed),
            now: now,
          )
          .status,
      HomeTodayTaskStatus.failed,
    );
    expect(
      service
          .resolve(
            tasks: const [],
            loadState: const TaskLoadState(),
            now: now,
            hasActiveJourney: true,
            isSignedIn: true,
          )
          .status,
      HomeTodayTaskStatus.loading,
    );

    final completed = _task(
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(hours: 1)),
    );
    final result = service.resolve(
      tasks: [completed],
      loadState: const TaskLoadState(status: TaskLoadStatus.loaded),
      now: now,
    );
    expect(result.status, HomeTodayTaskStatus.completed);
    expect(result.task?.id, completed.id);
  });

  test('実行可能Taskを完了表示より優先する', () {
    final actionable = _task(status: TaskStatus.ready);
    final result = service.resolve(
      tasks: [
        _task(id: 'completed', status: TaskStatus.completed, completedAt: now),
        actionable,
      ],
      loadState: const TaskLoadState(status: TaskLoadStatus.loaded),
      now: now,
      recommendedTask: actionable,
    );
    expect(result.status, HomeTodayTaskStatus.actionable);
    expect(result.task?.id, actionable.id);
  });

  testWidgets('HomeはTaskと親Mission・Questを一つの主操作で表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskControllerProvider.overrideWith(_HomeTaskController.new),
          taskLoadStateProvider.overrideWith(_LoadedTaskStateController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('渡航準備を整える  /  必要書類をそろえる'), findsOneWidget);
    expect(find.text('パスポートの有効期限を確認する'), findsOneWidget);
    expect(find.text('このTaskを始める'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('このTaskを始める'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _HomeTaskController extends TaskController {
  @override
  List<QuestraTask> build() => [_task(status: TaskStatus.ready)];
}

class _LoadedTaskStateController extends TaskLoadStateController {
  @override
  TaskLoadState build() => const TaskLoadState(status: TaskLoadStatus.loaded);
}

QuestraTask _task({
  String id = 'task-home',
  required TaskStatus status,
  DateTime? completedAt,
}) => QuestraTask(
  id: id,
  questId: 'quest-home',
  missionId: 'mission-home',
  questTitle: '渡航準備を整える',
  missionTitle: '必要書類をそろえる',
  title: 'パスポートの有効期限を確認する',
  action: 'パスポートを開き、有効期限が帰国予定日から6か月以上あるか確認する',
  doneCondition: '有効期限を確認し、必要なら更新日を決めている',
  estimatedEffortMinutes: 5,
  status: status,
  completedAt: completedAt,
);
