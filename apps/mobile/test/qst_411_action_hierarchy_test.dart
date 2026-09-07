import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_detail_screen.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_detail_screen.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  testWidgets('Mission shows one next Task action and parent context', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_ReadyTaskFixture.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('中間成果'), findsOneWidget);
    expect(find.text('今やること'), findsOneWidget);
    expect(find.text('次のTaskを始める'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mission-primary-action')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('親Quest、シンガポールへ行くを開く'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('現在のMission')),
      findsAtLeastNWidgets(1),
    );

    await tester.tap(find.text('次のTaskを始める'));
    await tester.pumpAndSettle();
    expect(find.text('Task destination'), findsOneWidget);
  });

  testWidgets('completed Tasks require separate Mission outcome confirmation', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_CompletedTaskFixture.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Missionの成果を確認'), findsOneWidget);
    expect(find.textContaining('Taskの完了とは別'), findsNothing);
    await tester.tap(find.text('Missionの成果を確認'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Taskの完了とは別'), findsOneWidget);
    expect(find.text('成果を確認した'), findsOneWidget);
    expect(find.text('まだ達成していない'), findsOneWidget);
  });

  testWidgets('Task links to its parent Mission and Quest', (tester) async {
    final router = _router(initialLocation: '/task-detail');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskControllerProvider.overrideWith(_ReadyTaskFixture.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('具体的な行動'), findsOneWidget);
    expect(find.bySemanticsLabel('親Quest、シンガポールへ行くを開く'), findsOneWidget);
    expect(find.bySemanticsLabel('親Mission、旅行日程を決めるを開く'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('現在のTask')), findsAtLeastNWidgets(1));

    await tester.tap(find.bySemanticsLabel('親Mission、旅行日程を決めるを開く'));
    await tester.pumpAndSettle();
    expect(find.text('Mission destination'), findsOneWidget);
  });

  testWidgets('missing parent data offers a safe Quest recovery route', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          missionControllerProvider.overrideWith(_EmptyMissionFixture.new),
          taskControllerProvider.overrideWith(_EmptyTaskFixture.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Missionが見つかりません。'), findsOneWidget);
    expect(find.text('Questへ戻る'), findsOneWidget);
    await tester.tap(find.text('Questへ戻る'));
    await tester.pumpAndSettle();
    expect(find.text('Quest destination'), findsOneWidget);
  });
}

GoRouter _router({String initialLocation = '/mission-detail'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/mission-detail',
      builder: (_, _) => const MissionDetailScreen(missionId: 'mission-1'),
    ),
    GoRoute(
      path: '/task-detail',
      builder: (_, _) => const TaskDetailScreen(taskId: 'task-1'),
    ),
    GoRoute(
      path: '/quest',
      builder: (_, _) => const Text('Quest destination'),
    ),
    GoRoute(
      path: '/quest/:questId',
      builder: (_, _) => const Text('Quest destination'),
      routes: [
        GoRoute(
          path: 'mission/:missionId',
          builder: (_, _) => const Text('Mission destination'),
          routes: [
            GoRoute(
              path: 'task/:taskId',
              builder: (_, _) => const Text('Task destination'),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-1',
      questId: 'quest-1',
      questTitle: 'シンガポールへ行く',
      title: '旅行日程を決める',
      description: '予約できる日程を確定する',
      objective: '同行者と合意した旅行日程が決まっている',
      doneCondition: '往復の日付を記録した',
      successCondition: '同行者と旅行日程に合意した',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    ),
  ];
}

QuestraTask _task(TaskStatus status) => QuestraTask(
  id: 'task-1',
  questId: 'quest-1',
  questTitle: 'シンガポールへ行く',
  missionId: 'mission-1',
  missionTitle: '旅行日程を決める',
  title: '候補日を3つ書き出す',
  action: 'カレンダーを見て候補日を3つ記録する',
  doneCondition: '候補日が3つ記録されている',
  status: status,
);

class _ReadyTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [_task(TaskStatus.ready)];
}

class _CompletedTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [_task(TaskStatus.completed)];
}

class _EmptyMissionFixture extends MissionController {
  @override
  List<Mission> build() => const [];
}

class _EmptyTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => const [];
}
