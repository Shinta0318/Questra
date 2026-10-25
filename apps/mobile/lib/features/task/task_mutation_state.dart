import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/durable_mutation.dart';
import '../../core/persistence/database_write_feedback.dart';
import 'task_model.dart';

enum TaskMutationStatus {
  idle,
  saving,
  saved,
  failed,
  offlinePending,
  conflict,
  cleanupPending,
}

enum TaskMutationKind { save, reorder }

class PendingTaskMutation {
  const PendingTaskMutation({
    required this.ownerId,
    required this.idempotencyKey,
    required this.desired,
    required this.previous,
    this.kind = TaskMutationKind.save,
    this.attempts = 0,
    this.queuedAt,
  });

  final String ownerId;
  final String idempotencyKey;
  final List<QuestraTask> desired;
  final List<QuestraTask> previous;
  final TaskMutationKind kind;
  final int attempts;
  final DateTime? queuedAt;

  PendingTaskMutation nextAttempt() => PendingTaskMutation(
    ownerId: ownerId,
    idempotencyKey: idempotencyKey,
    desired: desired,
    previous: previous,
    kind: kind,
    attempts: attempts + 1,
    queuedAt: queuedAt,
  );
}

class TaskMutationState {
  const TaskMutationState({
    this.status = TaskMutationStatus.idle,
    this.message,
    this.pending,
    this.conflictMissionIds = const {},
  });

  final TaskMutationStatus status;
  final String? message;
  final PendingTaskMutation? pending;
  final Set<String> conflictMissionIds;

  bool get isActive => status != TaskMutationStatus.idle;
  bool get canRetry =>
      pending != null &&
      (status == TaskMutationStatus.failed ||
          status == TaskMutationStatus.offlinePending);
  bool get canCleanup =>
      pending != null && status == TaskMutationStatus.cleanupPending;
  bool get needsConflictRefresh =>
      status == TaskMutationStatus.conflict && conflictMissionIds.isNotEmpty;
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
    final databaseFeedback = DatabaseWriteFeedback.from(error);
    state = TaskMutationState(
      status: offline
          ? TaskMutationStatus.offlinePending
          : TaskMutationStatus.failed,
      message: databaseFeedback != null
          ? 'Taskを保存できませんでした。${databaseFeedback.message}変更内容は保持されています。'
          : offline
          ? 'オフラインです。変更内容は保持されています。接続後に再試行してください。'
          : 'Taskを保存できませんでした。変更内容は保持されています。',
      pending: mutation,
    );
  }

  void conflict({bool? refreshed, Set<String> missionIds = const {}}) {
    state = TaskMutationState(
      status: TaskMutationStatus.conflict,
      message: switch (refreshed) {
        true => 'Taskが別の端末で更新されました。最新の内容を確認してください。',
        false => 'Taskが別の端末で更新されました。最新の内容を読み込めませんでした。再読み込みしてください。',
        null => 'Taskが先に更新されました。最新の内容を確認して、もう一度操作してください。',
      },
      conflictMissionIds: refreshed == false
          ? Set.unmodifiable(missionIds)
          : const {},
    );
  }

  void cleanupPending(PendingTaskMutation mutation) {
    state = TaskMutationState(
      status: TaskMutationStatus.cleanupPending,
      message: 'Taskは保存されました。端末内の再試行記録を整理してください。',
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
    if (state.canRetry || state.canCleanup || state.needsConflictRefresh) {
      return;
    }
    state = const TaskMutationState();
  }

  void discard() {
    state = const TaskMutationState();
  }
}
