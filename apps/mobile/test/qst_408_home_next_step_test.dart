import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/features/home/home_screen.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_load_state.dart';
import 'package:questra/features/task/task_model.dart';

import 'support/fixture_quest_controller.dart';

void main() {
  testWidgets('初回HomeはArc説明と一つの開始CTAだけを示す', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeScreen())),
    );
    await tester.pump();

    expect(find.text('Arc'), findsOneWidget);
    expect(find.text('タップして話す'), findsNothing);
    expect(find.text('確認して始める'), findsOneWidget);
    expect(find.text('今日の一歩'), findsNothing);
    expect(find.text('進行中のQuest'), findsNothing);
    expect(find.text('最近のTrail'), findsNothing);
    expect(find.text('次の航路'), findsNothing);
    expect(tester.getTopLeft(find.text('確認して始める')).dy, lessThan(700));
  });

  testWidgets('再訪Homeの主操作は選ばれたTask IDへ一度だけ進む', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final taskController = _ActionableTaskController();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/quest/:questId',
          builder: (context, state) => Scaffold(
            body: Text(
              '${state.pathParameters['questId']}:${state.uri.queryParameters['task']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskControllerProvider.overrideWith(() => taskController),
          taskLoadStateProvider.overrideWith(_LoadedTaskStateController.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('今日の一歩'), findsOneWidget);
    expect(find.text('渡航準備  /  航空券を決める'), findsOneWidget);
    expect(find.text('航空券の候補日を比較する'), findsOneWidget);
    expect(find.text('約20分'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('このTaskを始める'));
    await tester.pumpAndSettle();

    expect(taskController.startedTaskId, 'task-focus');
    expect(find.text('quest-focus:task-focus'), findsOneWidget);
  });

  testWidgets('Task読込失敗を空状態に見せず再試行を示す', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(FixtureQuestController.new),
          taskLoadStateProvider.overrideWith(_FailedTaskStateController.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('今日のTaskを読み込めませんでした'), findsOneWidget);
    expect(find.text('もう一度読み込む'), findsOneWidget);
    expect(find.text('今日の航路はまだ自由です'), findsNothing);
  });
}

class _ActionableTaskController extends TaskController {
  String? startedTaskId;

  @override
  List<QuestraTask> build() => [_task];

  @override
  Future<bool> start(String taskId) async {
    startedTaskId = taskId;
    return true;
  }
}

class _LoadedTaskStateController extends TaskLoadStateController {
  @override
  TaskLoadState build() => const TaskLoadState(status: TaskLoadStatus.loaded);
}

class _FailedTaskStateController extends TaskLoadStateController {
  @override
  TaskLoadState build() => const TaskLoadState(status: TaskLoadStatus.failed);
}

final _task = QuestraTask(
  id: 'task-focus',
  questId: 'quest-focus',
  missionId: 'mission-focus',
  questTitle: '渡航準備',
  missionTitle: '航空券を決める',
  title: '航空券の候補日を比較する',
  action: '候補日を二つ選び、料金と移動時間を比較する',
  doneCondition: '候補日ごとの料金と移動時間をメモしている',
  estimatedEffortMinutes: 20,
  status: TaskStatus.ready,
);
