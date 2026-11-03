import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_controller.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_detail_screen.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_screen.dart';

void main() {
  testWidgets('Task一覧は現行航路の実行可能なTaskだけを表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
        ],
        child: const MaterialApp(home: TaskScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('現行Task'), findsOneWidget);
    expect(find.text('古いQuestのTask'), findsNothing);
    expect(find.text('停止MissionのTask'), findsNothing);
    expect(find.text('保留Task'), findsNothing);
    expect(find.text('Arcのおすすめ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Task開始失敗を黙って無視しない', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
        ],
        child: const MaterialApp(home: TaskScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('開始'));
    await tester.pump();

    expect(
      find.text('Taskを開始できませんでした。通信とTaskの状態を確認して、もう一度お試しください。'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('停止MissionのTask詳細は開始操作を無効にする', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          questControllerProvider.overrideWith(_QuestFixture.new),
          missionControllerProvider.overrideWith(_MissionFixture.new),
          taskControllerProvider.overrideWith(_TaskFixture.new),
        ],
        child: const MaterialApp(home: TaskDetailScreen(taskId: 'paused')),
      ),
    );
    await tester.pump();

    expect(find.textContaining('現在の航路では実行できません'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(startButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  test('Controllerへの直接操作でも停止MissionのTaskを変更しない', () async {
    final container = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        taskControllerProvider.overrideWith(_RealTaskFixture.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    expect(await controller.start('paused'), isFalse);
    expect(await controller.complete('paused'), isFalse);
    expect(await controller.completeFromWorkspace('paused'), isFalse);
    expect(
      await controller.reschedule('paused', DateTime(2026, 12, 1)),
      isFalse,
    );
    expect(await controller.skip('paused'), isFalse);
    expect(
      container.read(taskControllerProvider).single.status,
      TaskStatus.ready,
    );
  });

  test('完了MissionのTaskはUndoでき、停止MissionのTaskはUndoできない', () async {
    final completed = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_CompletedMissionFixture.new),
        taskControllerProvider.overrideWith(_CompletedTaskFixture.new),
      ],
    );
    addTearDown(completed.dispose);
    expect(
      await completed.read(taskControllerProvider.notifier).reopen('finished'),
      isTrue,
    );
    expect(
      completed.read(taskControllerProvider).single.status,
      TaskStatus.pending,
    );

    final paused = ProviderContainer(
      overrides: [
        questControllerProvider.overrideWith(_QuestFixture.new),
        missionControllerProvider.overrideWith(_MissionFixture.new),
        taskControllerProvider.overrideWith(_PausedCompletedTaskFixture.new),
      ],
    );
    addTearDown(paused.dispose);
    expect(
      await paused.read(taskControllerProvider.notifier).reopen('paused'),
      isFalse,
    );
    expect(
      paused.read(taskControllerProvider).single.status,
      TaskStatus.completed,
    );
  });
}

class _QuestFixture extends QuestController {
  @override
  List<Quest> build() => [
    _quest('active', QuestStatus.active),
    _quest('archived', QuestStatus.archived),
  ];
}

class _MissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission('current', 'active', MissionRouteState.active),
    _mission('paused', 'active', MissionRouteState.paused),
    _mission('old', 'archived', MissionRouteState.active),
  ];
}

class _CompletedMissionFixture extends MissionController {
  @override
  List<Mission> build() => [
    _mission(
      'finished',
      'active',
      MissionRouteState.active,
      status: MissionStatus.completed,
    ),
  ];
}

class _TaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [
    _task('current', 'active', 'current', '現行Task'),
    _task('old', 'archived', 'old', '古いQuestのTask'),
    _task('paused', 'active', 'paused', '停止MissionのTask'),
    _task('blocked', 'active', 'current', '保留Task', TaskStatus.blocked),
  ];

  @override
  Future<bool> start(String taskId) async => false;
}

class _RealTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [
    _task('paused', 'active', 'paused', '停止MissionのTask'),
  ];
}

class _CompletedTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [
    _task('finished', 'active', 'finished', '完了Task', TaskStatus.completed),
  ];
}

class _PausedCompletedTaskFixture extends TaskController {
  @override
  List<QuestraTask> build() => [
    _task(
      'paused',
      'active',
      'paused',
      '停止Missionの完了Task',
      TaskStatus.completed,
    ),
  ];
}

Quest _quest(String id, QuestStatus status) => Quest(
  id: id,
  title: 'Quest $id',
  description: '達成したいこと',
  difficulty: QuestDifficulty.normal,
  status: status,
  visibility: QuestVisibility.private,
);

Mission _mission(
  String id,
  String questId,
  MissionRouteState routeState, {
  MissionStatus status = MissionStatus.todo,
}) => Mission(
  id: id,
  questId: questId,
  questTitle: 'Quest $questId',
  title: 'Mission $id',
  description: '行動をまとめる',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.normal,
  status: status,
  routeState: routeState,
);

QuestraTask _task(
  String id,
  String questId,
  String missionId,
  String title, [
  TaskStatus status = TaskStatus.ready,
]) => QuestraTask(
  id: id,
  questId: questId,
  missionId: missionId,
  title: title,
  action: '具体的な行動を行う',
  doneCondition: '行動を終えた',
  status: status,
);
