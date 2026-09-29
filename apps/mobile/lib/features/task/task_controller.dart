import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../mission/mission_controller.dart';
import '../quest/quest_controller.dart';
import '../quest/planning_preferences_controller.dart';
import '../trust/consent_controller.dart';
import '../trust/consent_purpose_registry_service.dart';
import 'task_model.dart';
import 'task_availability_service.dart';
import 'task_load_state.dart';
import 'task_mutation_state.dart';
import 'task_offline_queue_repository.dart';
import 'task_progress_service.dart';
import 'task_providers.dart';

final taskControllerProvider =
    NotifierProvider<TaskController, List<QuestraTask>>(TaskController.new);

class TaskController extends Notifier<List<QuestraTask>> {
  int _loadGeneration = 0;
  int _ownerGeneration = 0;
  final Map<String, Future<void>> _mutationTails = {};

  @override
  List<QuestraTask> build() {
    ref.listen(authControllerProvider.select((value) => value.profile?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _ownerGeneration++;
      state = const [];
      ref.read(taskLoadStateProvider.notifier).reset();
      ref.read(taskMutationControllerProvider.notifier).discard();
      if (next != null) {
        unawaited(_restorePending(next));
        unawaited(_loadCurrentQuests());
      }
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
      final ownerId = ref.read(authControllerProvider).profile!.id;
      unawaited(Future<void>.microtask(() => _restorePending(ownerId)));
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
    final loadState = ref.read(taskLoadStateProvider.notifier);
    final generation = ++_loadGeneration;
    if (questIds.isEmpty) {
      state = const [];
      loadState.loaded();
      return;
    }
    final ownerId = ref.read(authControllerProvider).profile?.id;
    loadState.loading();
    try {
      final loaded = await ref
          .read(taskRepositoryProvider)
          .findByQuestIds(questIds);
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != ownerId) {
        return;
      }
      state = loaded;
      _syncAllMissionProgress();
      loadState.loaded();
    } catch (_) {
      if (generation == _loadGeneration &&
          ref.read(authControllerProvider).profile?.id == ownerId) {
        loadState.failed();
      }
    }
  }

  Future<void> reload() => _loadCurrentQuests();

  Future<QuestraTask> addTask(QuestraTask task) async {
    final saved = await _persistBatch([task]);
    return saved.single;
  }

  Future<List<QuestraTask>> addTasks(List<QuestraTask> tasks) async {
    if (tasks.isEmpty) return const [];
    return _persistBatch(tasks);
  }

  Future<bool> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered,
  ) async {
    if (ordered.isEmpty) return true;
    if (ordered.any((task) => task.missionId != missionId)) return false;
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    try {
      return await _serializeTaskMutation(
        ownerId,
        ownerGeneration,
        () => _reorderMissionTasksNow(missionId, ordered),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _reorderMissionTasksNow(
    String missionId,
    List<QuestraTask> ordered,
  ) async {
    final latestById = {
      for (final task in state.where((task) => task.missionId == missionId))
        task.id: task,
    };
    if (ordered.map((task) => task.id).toSet().length != ordered.length ||
        ordered.any((task) => !latestById.containsKey(task.id))) {
      return false;
    }
    final desired = [
      for (var index = 0; index < ordered.length; index++)
        latestById[ordered[index].id]!.copyWith(orderIndex: index),
    ];
    final ids = desired.map((task) => task.id).toSet();
    final previous = state
        .where((task) => ids.contains(task.id))
        .toList(growable: false);
    if (previous.length != desired.length) return false;
    final mutation = PendingTaskMutation(
      ownerId: ref.read(authControllerProvider).profile?.id ?? 'local-preview',
      idempotencyKey: _mutationKey(desired),
      desired: List.unmodifiable(desired),
      previous: List.unmodifiable(previous),
      queuedAt: DateTime.now().toUtc(),
    );
    final ownerGeneration = _ownerGeneration;
    bool isCurrentOwner() =>
        ownerGeneration == _ownerGeneration &&
        (ref.read(authControllerProvider).profile?.id ?? 'local-preview') ==
            mutation.ownerId;
    final sync = ref.read(taskMutationControllerProvider.notifier);
    await _queueMutation(mutation);
    if (!isCurrentOwner()) return false;
    sync.saving(mutation);
    _merge(desired);
    try {
      final saved = await ref
          .read(taskRepositoryProvider)
          .reorderMissionTasks(
            missionId,
            desired,
            operationId: mutation.idempotencyKey,
          );
      if (!isCurrentOwner()) return false;
      _merge(saved);
      sync.saved('Taskの順番を更新しました。');
      await _clearQueuedMutation(mutation.ownerId);
      if (!isCurrentOwner()) return false;
      return true;
    } catch (error) {
      if (!isCurrentOwner()) return false;
      state = [...state.where((task) => !ids.contains(task.id)), ...previous];
      sync.failed(mutation, error);
      return false;
    }
  }

  Future<bool> updateTask(QuestraTask task) async {
    final observed = _find(task.id);
    if (observed == null) return false;
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    try {
      return await _serializeTaskMutation(ownerId, ownerGeneration, () async {
        final current = _find(task.id);
        if (!identical(current, observed) ||
            task.basedOnSnapshotRevision != current?.snapshotRevision) {
          ref.read(taskMutationControllerProvider.notifier).conflict();
          return false;
        }
        await _persistBatchNow([task]);
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> restoreRouteSnapshot(
    String questId,
    List<QuestraTask> snapshot,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    final snapshotIds = snapshot.map((task) => task.id).toSet();
    final current = state
        .where((task) => task.questId == questId)
        .toList(growable: false);
    for (final task in current.where(
      (task) => !snapshotIds.contains(task.id),
    )) {
      await repository.delete(task.id);
    }
    await repository.saveAll(snapshot);
    state = [...state.where((task) => task.questId != questId), ...snapshot];
    _syncMissions([...current, ...snapshot]);
  }

  Future<bool> start(String taskId) => _runTaskIntent(taskId, (task) {
    final canStart = const TaskAvailabilityService()
        .evaluate(task, forMission(task.missionId))
        .canStart;
    return canStart ? task.copyWith(status: TaskStatus.inProgress) : null;
  });

  Future<bool> complete(String taskId) => _runTaskIntent(taskId, (task) {
    final canComplete = const TaskAvailabilityService()
        .evaluate(task, forMission(task.missionId))
        .canComplete;
    return canComplete
        ? task.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
          )
        : null;
  });

  /// Workspace completion is intentionally one action. Dependency validation
  /// remains authoritative, but a ready Task does not require a separate
  /// "start" tap before it can be checked off.
  Future<bool> completeFromWorkspace(String taskId) =>
      _runTaskIntent(taskId, (task) {
        final availability = const TaskAvailabilityService().evaluate(
          task,
          forMission(task.missionId),
        );
        return availability.canStart || availability.canComplete
            ? task.copyWith(
                status: TaskStatus.completed,
                completedAt: DateTime.now(),
              )
            : null;
      });

  Future<bool> reopen(String taskId) => _runTaskIntent(
    taskId,
    (task) => task.status == TaskStatus.completed
        ? task.copyWith(status: TaskStatus.pending, clearCompletedAt: true)
        : null,
  );

  Future<bool> skip(String taskId) => _updateStatus(taskId, TaskStatus.skipped);

  Future<bool> block(String taskId) =>
      _updateStatus(taskId, TaskStatus.blocked);

  Future<bool> reschedule(String taskId, DateTime date) => _runTaskIntent(
    taskId,
    (task) => task.status == TaskStatus.completed
        ? null
        : task.copyWith(scheduledDate: date, status: TaskStatus.pending),
  );

  Future<bool> _updateStatus(
    String taskId,
    TaskStatus status, {
    DateTime? completedAt,
  }) => _runTaskIntent(
    taskId,
    (task) => task.status == TaskStatus.completed
        ? null
        : task.copyWith(
            status: status,
            completedAt: completedAt,
            clearCompletedAt: completedAt == null,
          ),
  );

  Future<bool> _runTaskIntent(
    String taskId,
    QuestraTask? Function(QuestraTask current) buildDesired,
  ) async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    try {
      return await _serializeTaskMutation(ownerId, ownerGeneration, () async {
        final current = _find(taskId);
        if (current == null) return false;
        final desired = buildDesired(current);
        if (desired == null) return false;
        await _persistBatchNow([desired]);
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<bool> retryPending() async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    try {
      return await _serializeTaskMutation(ownerId, ownerGeneration, () async {
        final mutationState = ref.read(taskMutationControllerProvider);
        final pending = mutationState.pending;
        if (!mutationState.canRetry || pending?.ownerId != ownerId) {
          return false;
        }
        try {
          await _persistBatchNow(pending!.desired, retryOf: pending);
          return true;
        } catch (_) {
          return false;
        }
      }, allowPending: true);
    } catch (_) {
      return false;
    }
  }

  Future<void> discardPending() async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    try {
      await _serializeTaskMutation(ownerId, ownerGeneration, () async {
        final mutationState = ref.read(taskMutationControllerProvider);
        final pending = mutationState.pending;
        if (!mutationState.canRetry || pending?.ownerId != ownerId) return;
        await _clearQueuedMutation(ownerId);
        if (_isCurrentOwner(ownerId, ownerGeneration) &&
            identical(
              ref.read(taskMutationControllerProvider).pending,
              pending,
            )) {
          ref.read(taskMutationControllerProvider.notifier).discard();
        }
      }, allowPending: true);
    } catch (_) {
      // A switched owner must never discard the prior owner's retry.
    }
  }

  Future<List<QuestraTask>> _persistBatch(
    List<QuestraTask> desired, {
    PendingTaskMutation? retryOf,
  }) {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    return _serializeTaskMutation(
      ownerId,
      ownerGeneration,
      () => _persistBatchNow(desired, retryOf: retryOf),
      allowPending: retryOf != null,
    );
  }

  Future<List<QuestraTask>> _persistBatchNow(
    List<QuestraTask> desired, {
    PendingTaskMutation? retryOf,
  }) async {
    final ids = desired.map((task) => task.id).toSet();
    final previous =
        retryOf?.previous ??
        state.where((task) => ids.contains(task.id)).toList(growable: false);
    final mutation =
        retryOf?.nextAttempt() ??
        PendingTaskMutation(
          ownerId:
              ref.read(authControllerProvider).profile?.id ?? 'local-preview',
          idempotencyKey: _mutationKey(desired),
          desired: List.unmodifiable(desired),
          previous: List.unmodifiable(previous),
          queuedAt: DateTime.now().toUtc(),
        );
    final ownerGeneration = _ownerGeneration;
    bool isCurrentOwner() =>
        ownerGeneration == _ownerGeneration &&
        (ref.read(authControllerProvider).profile?.id ?? 'local-preview') ==
            mutation.ownerId;
    final sync = ref.read(taskMutationControllerProvider.notifier);
    await _queueMutation(mutation);
    if (!isCurrentOwner()) throw StateError('Task owner changed during save');
    sync.saving(mutation);
    _merge(desired);
    _syncMissions(desired);
    try {
      final repository = ref.read(taskRepositoryProvider);
      final isAtomicCompletion =
          repository.supportsAtomicCompletion &&
          desired.length == 1 &&
          previous.length == 1 &&
          previous.single.status != TaskStatus.completed &&
          desired.single.status == TaskStatus.completed;
      final saved = isAtomicCompletion
          ? [
              await repository.completeAtomically(
                desired.single,
                operationId: mutation.idempotencyKey,
              ),
            ]
          : await repository.saveAll(desired);
      if (!isCurrentOwner()) throw StateError('Task owner changed during save');
      _merge(saved);
      _syncMissions(saved);
      for (final task in saved) {
        final before = previous.where((item) => item.id == task.id).firstOrNull;
        unawaited(_rememberTaskTransition(before, task));
        if (!isAtomicCompletion &&
            before?.status != TaskStatus.completed &&
            task.status == TaskStatus.completed) {
          unawaited(
            ref
                .read(authControllerProvider.notifier)
                .awardStardust(
                  event: StardustEvent.taskCompleted,
                  sourceId: task.id,
                ),
          );
        }
      }
      sync.saved(
        saved.length == 1 ? 'Taskを保存しました。' : '${saved.length}件のTaskを保存しました。',
      );
      await _clearQueuedMutation(mutation.ownerId);
      if (!isCurrentOwner()) throw StateError('Task owner changed during save');
      return saved;
    } catch (error) {
      if (!isCurrentOwner()) rethrow;
      state = [...state.where((task) => !ids.contains(task.id)), ...previous];
      _syncMissions([...desired, ...previous]);
      sync.failed(mutation, error);
      rethrow;
    }
  }

  bool _isCurrentOwner(String ownerId, int generation) =>
      generation == _ownerGeneration &&
      (ref.read(authControllerProvider).profile?.id ?? 'local-preview') ==
          ownerId;

  Future<T> _serializeTaskMutation<T>(
    String ownerId,
    int ownerGeneration,
    Future<T> Function() run, {
    bool allowPending = false,
  }) async {
    final previous = _mutationTails[ownerId];
    final completed = Completer<void>();
    final tail = completed.future;
    _mutationTails[ownerId] = tail;
    try {
      if (previous != null) await previous;
      if (!_isCurrentOwner(ownerId, ownerGeneration)) {
        throw StateError('Task owner changed during save');
      }
      if (!allowPending && ref.read(taskMutationControllerProvider).canRetry) {
        throw StateError('Resolve pending Task changes before saving again');
      }
      return await run();
    } finally {
      if (identical(_mutationTails[ownerId], tail)) {
        _mutationTails.remove(ownerId);
      }
      completed.complete();
    }
  }

  Future<void> _restorePending(String ownerId) async {
    final pending = await ref
        .read(taskOfflineQueueRepositoryProvider)
        .load(ownerId);
    if (pending == null ||
        pending.ownerId != ownerId ||
        ref.read(authControllerProvider).profile?.id != ownerId) {
      return;
    }
    ref.read(taskMutationControllerProvider.notifier).restore(pending);
  }

  Future<void> _queueMutation(PendingTaskMutation mutation) async {
    if (mutation.ownerId == 'local-preview') return;
    await ref
        .read(taskOfflineQueueRepositoryProvider)
        .save(mutation.ownerId, mutation);
  }

  Future<void> _clearQueuedMutation(String ownerId) async {
    if (ownerId == 'local-preview') return;
    await ref.read(taskOfflineQueueRepositoryProvider).clear(ownerId);
  }

  Future<void> _rememberTaskTransition(
    QuestraTask? previous,
    QuestraTask current,
  ) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) return;
    final consent = ref
        .read(consentControllerProvider)
        .value?[ConsentPurpose.arcPersonalization];
    if (consent?.isGranted != true) return;
    try {
      final memories = await ref
          .read(taskMemoryEventServiceProvider)
          .recordTransition(
            userId: userId,
            previous: previous,
            current: current,
            consentGranted: true,
          );
      if (memories.isNotEmpty) ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Task persistence remains authoritative when optional Memory sync fails.
    }
  }

  void _merge(Iterable<QuestraTask> tasks) {
    final replacements = {for (final task in tasks) task.id: task};
    state = [
      for (final item in state) replacements.remove(item.id) ?? item,
      ...replacements.values,
    ];
  }

  void _syncMissions(Iterable<QuestraTask> tasks) {
    for (final missionId in tasks.map((task) => task.missionId).toSet()) {
      _syncMission(missionId);
    }
  }

  String _mutationKey(List<QuestraTask> tasks) {
    final ids = tasks.map((task) => task.id).toList()..sort();
    return 'task-upsert:${ids.join(',')}';
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
