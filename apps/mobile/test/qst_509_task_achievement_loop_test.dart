import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:questra/features/arc/arc_celebration_service.dart';
import 'package:questra/features/task/task_achievement_flow.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  test('Task完了後は同じMissionの実行可能な次Taskを優先する', () {
    final completed = _task(
      id: 'done',
      title: '候補日を決める',
      status: TaskStatus.completed,
      orderIndex: 0,
    );
    final next = _task(
      id: 'next',
      title: '同行者へ確認する',
      status: TaskStatus.pending,
      orderIndex: 1,
      dependencyIds: const ['done'],
    );
    final otherMission = _task(
      id: 'other',
      title: '予算を調べる',
      missionId: 'mission-budget',
      missionTitle: '予算を整える',
      status: TaskStatus.pending,
      orderIndex: 0,
    );

    final plan = const TaskAchievementService().build(
      completedTask: completed,
      allTasks: [completed, next, otherMission],
    );

    expect(plan.nextTask?.id, next.id);
    expect(plan.missionReadyForReview, isFalse);
    expect(plan.message, contains(next.title));
    expect(plan.nextActionLabel, '次のTaskを見る');
  });

  test('必須Taskが揃った場合はMission成果確認を次の一歩にする', () {
    final completed = _task(
      id: 'done',
      title: '候補日を決める',
      status: TaskStatus.completed,
    );
    final plan = const TaskAchievementService().build(
      completedTask: completed,
      allTasks: [completed],
    );

    expect(plan.missionReadyForReview, isTrue);
    expect(plan.nextActionLabel, 'Missionの成果を確認');
    expect(plan.message, contains('必須Task'));
  });

  test('ArcはTask完了そのものを祝い、Trailを自動生成しない', () {
    final moment = const ArcCelebrationService().build(
      event: ArcCelebrationEvent.taskCompleted,
      subject: '候補日を決める',
    );

    expect(moment.title, '今日の一歩を完了');
    expect(moment.message, contains('候補日を決める'));
    expect(moment.message, contains('Trailに残す'));
  });

  testWidgets('完了モーメントから親付きTrail作成へ進める', (tester) async {
    final completed = _task(
      id: 'task-date',
      title: '候補日を決める',
      status: TaskStatus.completed,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: FilledButton(
              onPressed: () => showTaskAchievementJourney(
                context: context,
                completedTask: completed,
                allTasks: [completed],
                onUndo: () async => true,
              ),
              child: const Text('完了モーメントを開く'),
            ),
          ),
        ),
        GoRoute(
          path: '/trail',
          builder: (context, state) => Scaffold(
            body: Text(
              'trail:${state.uri.queryParameters['questId']}:'
              '${state.uri.queryParameters['missionId']}:'
              '${state.uri.queryParameters['taskId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );

    await tester.tap(find.text('完了モーメントを開く'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('task-achievement-card')), findsOneWidget);
    expect(find.text('Trailに残す'), findsOneWidget);
    expect(find.text('Missionの成果を確認'), findsOneWidget);

    final trailAction = find.byKey(const ValueKey('task-achievement-trail'));
    await tester.ensureVisible(trailAction);
    await tester.pump();
    await tester.tap(trailAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('trail:quest-singapore:mission-schedule:task-date'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

QuestraTask _task({
  required String id,
  required String title,
  required TaskStatus status,
  String missionId = 'mission-schedule',
  String missionTitle = '旅行日程を決める',
  int orderIndex = 0,
  List<String> dependencyIds = const [],
}) => QuestraTask(
  id: id,
  questId: 'quest-singapore',
  questTitle: 'シンガポールへ行く',
  missionId: missionId,
  missionTitle: missionTitle,
  title: title,
  action: title,
  doneCondition: '$titleを確認できたら完了',
  status: status,
  orderIndex: orderIndex,
  dependencyIds: dependencyIds,
);
