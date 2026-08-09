import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_model.dart';

enum TaskMutationStatus { idle, saving, saved, failed, offlinePending }

class PendingTaskMutation {
  const PendingTaskMutation({
    required this.ownerId,
    required this.idempotencyKey,
    required this.desired,
    required this.previous,
    this.attempts = 0,
    this.queuedAt,
  });

  final String ownerId;
  final String idempotencyKey;
  final List<QuestraTask> desired;
  final List<QuestraTask> previous;
  final int attempts;
  final DateTime? queuedAt;

  PendingTaskMutation nextAttempt() => PendingTaskMutation(
    ownerId: ownerId,
    idempotencyKey: idempotencyKey,
    desired: desired,
    previous: previous,
    attempts: attempts + 1,
    queuedAt: queuedAt,
  );
}

class TaskMutationState {
  const TaskMutationState({
    this.status = TaskMutationStatus.idle,
    this.message,
    this.pending,
  });

  final TaskMutationStatus status;
  final String? message;
  final PendingTaskMutation? pending;

  bool get isActive => status != TaskMutationStatus.idle;
  bool get canRetry =>
      pending != null &&
      (status == TaskMutationStatus.failed ||
          status == TaskMutationStatus.offlinePending);
}

final taskMutationControllerProvider =
    NotifierProvider<TaskMutationStateController, TaskMutationState>(
      TaskMutationStateController.new,
    );

class TaskMutationStateController extends Notifier<TaskMutationState> {
  @override
  TaskMutationState build() => const TaskMutationState();

  void saving(PendingTaskMutation mutation) {
    state = TaskMutationState(
      status: TaskMutationStatus.saving,
      message: mutation.attempts == 0
          ? 'Taskを保存しています...'
          : 'Taskの保存を再試行しています...',
      pending: mutation,
    );
  }

  void saved([String message = 'Taskを保存しました。']) {
    state = TaskMutationState(
      status: TaskMutationStatus.saved,
      message: message,
    );
  }

  void failed(PendingTaskMutation mutation, Object error) {
    final offline = isOfflineFailure(error);
    state = TaskMutationState(
      status: offline
          ? TaskMutationStatus.offlinePending
          : TaskMutationStatus.failed,
      message: offline
          ? 'オフラインです。変更内容は保持されています。接続後に再試行してください。'
          : 'Taskを保存できませんでした。変更内容は保持されています。',
      pending: mutation,
    );
  }

  void restore(PendingTaskMutation mutation) {
    state = TaskMutationState(
      status: TaskMutationStatus.offlinePending,
      message: '未送信のTask変更があります。内容を確認して再試行してください。',
      pending: mutation,
    );
  }

  void clear() {
    if (state.canRetry) return;
    state = const TaskMutationState();
  }

  void discard() {
    state = const TaskMutationState();
  }
}

bool isOfflineFailure(Object error) {
  final value = error.toString().toLowerCase();
  return value.contains('failed host lookup') ||
      value.contains('network is unreachable') ||
      value.contains('network request failed') ||
      value.contains('xmlhttprequest error') ||
      value.contains('socketexception') ||
      value.contains('offline');
}
