import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/signal/task_signal_model.dart';
import 'package:questra/features/signal/task_signal_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  const service = TaskSignalService();
  final now = DateTime(2026, 8, 9, 12);

  test('期限SignalはTaskと親Mission・QuestのIDを保持する', () {
    final signals = service.generate(
      tasks: [
        _task(id: 'task-due', dueDate: DateTime(2026, 8, 9), updatedAt: now),
      ],
      now: now,
    );

    expect(signals.single.type, TaskSignalType.dueToday);
    expect(signals.single.taskId, 'task-due');
    expect(signals.single.questId, 'quest-1');
    expect(signals.single.missionId, 'mission-1');
  });

  test('保留中または前提未完了のTaskを急かさない', () {
    final signals = service.generate(
      tasks: [
        _task(
          id: 'blocked',
          status: TaskStatus.blocked,
          dueDate: DateTime(2026, 8, 8),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
        _task(
          id: 'waiting',
          dependencies: const ['prerequisite'],
          dueDate: DateTime(2026, 8, 8),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
        _task(id: 'prerequisite', updatedAt: now),
      ],
      now: now,
      frequency: SignalFrequency.frequent,
    );

    expect(signals.map((signal) => signal.taskId), isNot(contains('blocked')));
    expect(signals.map((signal) => signal.taskId), isNot(contains('waiting')));
  });

  test('静かめ設定では穏やかな開始Signalを表示しない', () {
    final signals = service.generate(
      tasks: [_task(id: 'ready', updatedAt: now)],
      now: now,
      frequency: SignalFrequency.quiet,
    );

    expect(signals, isEmpty);
  });

  test('通知同意がなければGatewayを呼ばない', () async {
    final gateway = _RecordingGateway();
    final decision = await const TaskSignalNotificationCoordinator().deliver(
      signal: _signal(),
      preferences: const TaskSignalPreferences(),
      now: now,
      gateway: gateway,
    );

    expect(decision, TaskSignalDeliveryDecision.suppressedWithoutConsent);
    expect(gateway.delivered, isEmpty);
  });

  test('同意済みでも静音時間中は通知しない', () async {
    final gateway = _RecordingGateway();
    final decision = await const TaskSignalNotificationCoordinator().deliver(
      signal: _signal(),
      preferences: const TaskSignalPreferences(notificationsEnabled: true),
      now: DateTime(2026, 8, 9, 23),
      gateway: gateway,
    );

    expect(decision, TaskSignalDeliveryDecision.suppressedDuringQuietHours);
    expect(gateway.delivered, isEmpty);
  });

  test('同意済みかつ静音時間外だけ通知境界へ渡す', () async {
    final gateway = _RecordingGateway();
    final decision = await const TaskSignalNotificationCoordinator().deliver(
      signal: _signal(),
      preferences: const TaskSignalPreferences(notificationsEnabled: true),
      now: now,
      gateway: gateway,
    );

    expect(decision, TaskSignalDeliveryDecision.deliver);
    expect(gateway.delivered, hasLength(1));
  });
}

QuestraTask _task({
  required String id,
  TaskStatus status = TaskStatus.pending,
  DateTime? dueDate,
  DateTime? updatedAt,
  List<String> dependencies = const [],
}) => QuestraTask(
  id: id,
  questId: 'quest-1',
  missionId: 'mission-1',
  questTitle: '星を目指す',
  missionTitle: '準備する',
  title: '必要な情報を確認する',
  action: '公式情報を一つ確認する',
  doneCondition: '確認結果が保存されている',
  status: status,
  dependencyIds: dependencies,
  dueDate: dueDate,
  updatedAt: updatedAt,
);

TaskSignal _signal() => const TaskSignal(
  type: TaskSignalType.dueToday,
  severity: TaskSignalSeverity.focus,
  taskId: 'task-1',
  questId: 'quest-1',
  missionId: 'mission-1',
  title: '今日が期限のTask',
  message: '今できる一歩だけ確認しよう。',
);

class _RecordingGateway implements TaskSignalNotificationGateway {
  final List<TaskSignal> delivered = [];

  @override
  Future<void> schedule(TaskSignal signal) async => delivered.add(signal);
}
