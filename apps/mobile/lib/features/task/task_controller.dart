import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../mission/mission_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/planning_preferences_controller.dart';
import 'task_model.dart';
import 'task_progress_service.dart';
import 'task_providers.dart';

final taskControllerProvider =
    NotifierProvider<TaskController, List<QuestraTask>>(TaskController.new);

class TaskController extends Notifier<List<QuestraTask>> {
  @override
  List<QuestraTask> build() {
    ref.listen(authControllerProvider.select((value) => value.profile?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      state = const [];
      if (next != null) unawaited(_loadCurrentQuests());
    });
    ref.listen(questControllerProvider, (previous, next) {
      if (ref.read(authControllerProvider).profile != null) {
        unawaited(
          loadForQuestIds(
            next.map((quest) => quest.id).toList(growable: false),
          ),
        );
      }
    });
    if (ref.read(authControllerProvider).profile != null) {
      unawaited(Future<void>.microtask(_loadCurrentQuests));
    }
    return const [];
  }

  QuestraTask? get todaysTask {
    final minutes = ref
        .read(planningPreferencesControllerProvider)
        .availability
        .totalMinutes;
    return const TaskProgressService().recommendToday(
      state,
      availableMinutes: minutes > 0 ? minutes : null,
    );
  }

  List<QuestraTask> forMission(String missionId) =>
      state.where((task) => task.missionId == missionId).toList(growable: false)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  Future<void> loadForQuestIds(List<String> questIds) async {
    if (questIds.isEmpty) {
      state = const [];
      return;
    }
    try {
      state = await ref.read(taskRepositoryProvider).findByQuestIds(questIds);
      _syncAllMissionProgress();
    } catch (_) {
      // Existing Quest/Mission flows remain usable before migration 022 is deployed.
    }
  }

  Future<QuestraTask> addTask(QuestraTask task) async {
    final saved = await ref.read(taskRepositoryProvider).save(task);
    state = [...state.where((item) => item.id != saved.id), saved];
    _syncMission(saved.missionId);
    return saved;
  }

  Future<void> start(String taskId) =>
      _updateStatus(taskId, TaskStatus.inProgress);

  Future<void> complete(String taskId) =>
      _updateStatus(taskId, TaskStatus.completed, completedAt: DateTime.now());

  Future<void> skip(String taskId) => _updateStatus(taskId, TaskStatus.skipped);

  Future<void> block(String taskId) =>
      _updateStatus(taskId, TaskStatus.blocked);

  Future<void> reschedule(String taskId, DateTime date) async {
    final task = _find(taskId);
    if (task == null || task.status == TaskStatus.completed) return;
    await _save(task.copyWith(scheduledDate: date, status: TaskStatus.pending));
  }

  Future<void> _updateStatus(
    String taskId,
    TaskStatus status, {
    DateTime? completedAt,
  }) async {
    final task = _find(taskId);
    if (task == null || task.status == TaskStatus.completed) return;
    await _save(
      task.copyWith(
        status: status,
        completedAt: completedAt,
        clearCompletedAt: completedAt == null,
      ),
    );
  }

  Future<void> _save(QuestraTask task) async {
    final saved = await ref.read(taskRepositoryProvider).save(task);
    state = [
      for (final item in state)
        if (item.id == saved.id) saved else item,
    ];
    _syncMission(saved.missionId);
  }

  QuestraTask? _find(String taskId) {
    for (final task in state) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  Future<void> _loadCurrentQuests() => loadForQuestIds(
    ref
        .read(questControllerProvider)
        .map((quest) => quest.id)
        .toList(growable: false),
  );

  void _syncAllMissionProgress() {
    for (final missionId in state.map((task) => task.missionId).toSet()) {
      _syncMission(missionId);
    }
  }

  void _syncMission(String missionId) {
    final snapshot = const TaskProgressService().forMission(
      forMission(missionId),
    );
    ref
        .read(missionControllerProvider.notifier)
        .applyTaskProgress(
          missionId,
          progressPercent: snapshot.percent,
          allRequiredTasksCompleted: snapshot.allRequiredCompleted,
        );
  }
}
