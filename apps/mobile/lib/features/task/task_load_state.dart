import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TaskLoadStatus { idle, loading, loaded, failed }

class TaskLoadState {
  const TaskLoadState({this.status = TaskLoadStatus.idle, this.message});

  final TaskLoadStatus status;
  final String? message;
}

final taskLoadStateProvider =
    NotifierProvider<TaskLoadStateController, TaskLoadState>(
      TaskLoadStateController.new,
    );

class TaskLoadStateController extends Notifier<TaskLoadState> {
  @override
  TaskLoadState build() => const TaskLoadState();

  void loading() {
    state = const TaskLoadState(status: TaskLoadStatus.loading);
  }

  void loaded() {
    state = const TaskLoadState(status: TaskLoadStatus.loaded);
  }

  void failed() {
    state = const TaskLoadState(
      status: TaskLoadStatus.failed,
      message: '今日のTaskを読み込めませんでした。',
    );
  }

  void reset() {
    state = const TaskLoadState();
  }
}
