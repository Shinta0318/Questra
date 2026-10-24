import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/performance/performance_limits.dart';
import '../auth/auth_controller.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../mission/mission_controller.dart';
import '../mission/mission_model.dart';
import '../mission/mission_providers.dart';
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
import 'task_repository.dart';

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
    final missionIds = state
        .where((task) => questIds.contains(task.questId))
        .map((task) => task.missionId)
        .toSet();
    loadState.loading();
    try {
      final loaded = await ref
          .read(taskRepositoryProvider)
          .findByQuestIds(questIds);
      missionIds.addAll(loaded.map((task) => task.missionId));
      final authoritative = await _fetchAuthoritativeMissions(
        missionIds,
        loaded,
      );
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != ownerId) {
        return;
      }
      if (ref.read(taskRepositoryProvider).supportsAtomicCompletion) {
        ref
            .read(missionControllerProvider.notifier)
            .applyAuthoritativeSnapshots(authoritative);
      }
      state = loaded;
      _syncAllMissionProgress();
      loadState.loaded();
    } catch (_) {
      if (generation == _loadGeneration &&
          ref.read(authControllerProvider).profile?.id == ownerId) {
        if (ref.read(taskRepositoryProvider).supportsAtomicCompletion) {
          ref
              .read(missionControllerProvider.notifier)
              .markAuthorityUnknown(missionIds);
        }
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
    if (ordered.length != latestById.length ||
        ordered.map((task) => task.id).toSet().length != ordered.length ||
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
      kind: TaskMutationKind.reorder,
      queuedAt: DateTime.now().toUtc(),
    );
    return _persistReorderNow(mutation);
  }

  Future<bool> _persistReorderNow(PendingTaskMutation mutation) async {
    final desired = mutation.desired;
    final previous = mutation.previous;
    if (desired.isEmpty ||
        desired.any((task) => task.missionId != desired.first.missionId)) {
      return false;
    }
    final missionId = desired.first.missionId;
    final ids = desired.map((task) => task.id).toSet();
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
      try {
        await _clearQueuedMutation(mutation.ownerId);
        if (!isCurrentOwner()) return false;
        sync.saved('Taskの順番を更新しました。');
      } catch (_) {
        if (!isCurrentOwner()) return false;
        sync.cleanupPending(mutation);
      }
      if (!isCurrentOwner()) return false;
      return true;
    } catch (error) {
      if (!isCurrentOwner()) return false;
      state = [...state.where((task) => !ids.contains(task.id)), ...previous];
      if (error is TaskVersionConflictException) {
        try {
          await _clearQueuedMutation(mutation.ownerId);
        } catch (cleanupError) {
          sync.failed(mutation, cleanupError);
          return false;
        }
        final refreshed = await _refreshMissionsAfterConflict(
          {missionId},
          mutation.ownerId,
          ownerGeneration,
        );
        if (isCurrentOwner()) {
          sync.conflict(refreshed: refreshed, missionIds: {missionId});
        }
      } else {
        sync.failed(mutation, error);
      }
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
    final current = state
        .where((task) => task.questId == questId)
        .toList(growable: false);
    final restored = await repository.replaceQuestTasks(
      questId,
      current,
      snapshot,
    );
    state = [...state.where((task) => task.questId != questId), ...restored];
    _syncMissions([...current, ...restored]);
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
        if (pending?.ownerId != ownerId) {
          return false;
        }
        if (mutationState.canCleanup) {
          try {
            await _clearQueuedMutation(ownerId);
            if (!_isCurrentOwner(ownerId, ownerGeneration)) return false;
            ref.read(taskMutationControllerProvider.notifier).saved();
            return true;
          } catch (_) {
            return false;
          }
        }
        if (!mutationState.canRetry) return false;
        try {
          if (pending!.kind == TaskMutationKind.reorder) {
            return await _persistReorderNow(pending.nextAttempt());
          }
          await _persistBatchNow(pending.desired, retryOf: pending);
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
    final repository = ref.read(taskRepositoryProvider);
    await _queueMutation(mutation);
    if (!isCurrentOwner()) throw StateError('Task owner changed during save');
    sync.saving(mutation);
    _merge(desired);
    if (!repository.supportsAtomicCompletion) _syncMissions(desired);
    try {
      final isAtomicCompletion =
          repository.supportsAtomicCompletion &&
          desired.length == 1 &&
          previous.length == 1 &&
          previous.single.status != TaskStatus.completed &&
          desired.single.status == TaskStatus.completed;
      final isAtomicReopen =
          repository.supportsAtomicCompletion &&
          desired.length == 1 &&
          previous.length == 1 &&
          previous.single.status == TaskStatus.completed &&
          desired.single.status == TaskStatus.pending &&
          desired.single.completedAt == null;
      final isVersionedUpdate =
          repository.supportsAtomicCompletion &&
          desired.length == 1 &&
          previous.length == 1 &&
          !isAtomicCompletion &&
          !isAtomicReopen;
      final saved = isAtomicCompletion
          ? [
              await repository.completeAtomically(
                desired.single,
                operationId: mutation.idempotencyKey,
              ),
            ]
          : isAtomicReopen
          ? [
              await repository.reopenAtomically(
                desired.single,
                operationId: mutation.idempotencyKey,
              ),
            ]
          : isVersionedUpdate
          ? [
              await repository.updateWithVersion(
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
      try {
        await _clearQueuedMutation(mutation.ownerId);
        if (!isCurrentOwner()) {
          throw StateError('Task owner changed during save');
        }
        sync.saved(
          saved.length == 1 ? 'Taskを保存しました。' : '${saved.length}件のTaskを保存しました。',
        );
      } catch (_) {
        if (!isCurrentOwner()) {
          throw StateError('Task owner changed during save');
        }
        sync.cleanupPending(mutation);
      }
      if (!isCurrentOwner()) throw StateError('Task owner changed during save');
      return saved;
    } catch (error) {
      if (!isCurrentOwner()) rethrow;
      state = [...state.where((task) => !ids.contains(task.id)), ...previous];
      if (!repository.supportsAtomicCompletion) {
        _syncMissions([...desired, ...previous]);
      }
      if (error is TaskVersionConflictException) {
        try {
          await _clearQueuedMutation(mutation.ownerId);
        } catch (cleanupError) {
          sync.failed(mutation, cleanupError);
          rethrow;
        }
        final refreshed = await _refreshMissionsAfterConflict(
          desired.map((task) => task.missionId).toSet(),
          mutation.ownerId,
          ownerGeneration,
        );
        if (isCurrentOwner()) {
          sync.conflict(
            refreshed: refreshed,
            missionIds: desired.map((task) => task.missionId).toSet(),
          );
        }
      } else {
        sync.failed(mutation, error);
      }
      rethrow;
    }
  }

  bool _isCurrentOwner(String ownerId, int generation) =>
      generation == _ownerGeneration &&
      (ref.read(authControllerProvider).profile?.id ?? 'local-preview') ==
          ownerId;

  Future<bool> refreshConflict() async {
    final mutation = ref.read(taskMutationControllerProvider);
    if (!mutation.needsConflictRefresh) return false;
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    final ownerGeneration = _ownerGeneration;
    final refreshed = await _refreshMissionsAfterConflict(
      mutation.conflictMissionIds,
      ownerId,
      ownerGeneration,
    );
    if (_isCurrentOwner(ownerId, ownerGeneration) &&
        identical(ref.read(taskMutationControllerProvider), mutation) &&
        refreshed) {
      ref
          .read(taskMutationControllerProvider.notifier)
          .conflict(refreshed: true);
    }
    return refreshed;
  }

  Future<bool> refreshMissionAuthority(String missionId) async {
    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? 'local-preview';
    return _refreshMissionsAfterConflict(
      {missionId},
      ownerId,
      _ownerGeneration,
    );
  }

  Future<bool> _refreshMissionsAfterConflict(
    Set<String> missionIds,
    String ownerId,
    int ownerGeneration,
  ) async {
    final loadGeneration = ++_loadGeneration;
    final refreshed = <QuestraTask>[];
    try {
      for (final missionId in missionIds) {
        final tasks = await ref
            .read(taskRepositoryProvider)
            .findByMission(
              missionId,
              limit: QuestraPerformanceLimits.taskListLimit + 1,
            );
        if (tasks.length > QuestraPerformanceLimits.taskListLimit ||
            tasks.any((task) => task.missionId != missionId)) {
          throw StateError('Taskの最新状態を確認できませんでした。');
        }
        refreshed.addAll(tasks);
      }
      final authoritative = await _fetchAuthoritativeMissions(
        missionIds,
        refreshed,
      );
      if (!_isCurrentOwner(ownerId, ownerGeneration) ||
          loadGeneration != _loadGeneration) {
        return false;
      }
      if (ref.read(taskRepositoryProvider).supportsAtomicCompletion) {
        ref
            .read(missionControllerProvider.notifier)
            .applyAuthoritativeSnapshots(authoritative);
      }
      state = [
        ...state.where((task) => !missionIds.contains(task.missionId)),
        ...refreshed,
      ];
      for (final missionId in missionIds) {
        _syncMission(missionId);
      }
      return true;
    } catch (_) {
      if (_isCurrentOwner(ownerId, ownerGeneration) &&
          loadGeneration == _loadGeneration &&
          ref.read(taskRepositoryProvider).supportsAtomicCompletion) {
        ref
            .read(missionControllerProvider.notifier)
            .markAuthorityUnknown(missionIds);
      }
      return false;
    }
  }

  Future<List<Mission>> _fetchAuthoritativeMissions(
    Set<String> missionIds,
    Iterable<QuestraTask> tasks,
  ) async {
    if (!ref.read(taskRepositoryProvider).supportsAtomicCompletion ||
        missionIds.isEmpty) {
      return const [];
    }
    final questByMission = <String, String>{};
    for (final task in tasks) {
      final previous = questByMission[task.missionId];
      if (previous != null && previous != task.questId) {
        throw StateError('TaskとMissionの所属を確認できませんでした。');
      }
      questByMission[task.missionId] = task.questId;
    }
    final ids = missionIds.toList(growable: false);
    final loaded = <Mission>[];
    for (
      var index = 0;
      index < ids.length;
      index += QuestraPerformanceLimits.missionListLimit
    ) {
      final next = index + QuestraPerformanceLimits.missionListLimit;
      final end = next < ids.length ? next : ids.length;
      loaded.addAll(
        await ref
            .read(missionRepositoryProvider)
            .findByIds(ids.sublist(index, end)),
      );
    }
    if (loaded.length != missionIds.length ||
        loaded.map((mission) => mission.id).toSet().length !=
            missionIds.length ||
        loaded.any(
          (mission) =>
              !missionIds.contains(mission.id) ||
              mission.routeState == MissionRouteState.removed ||
              (questByMission[mission.id] != null &&
                  questByMission[mission.id] != mission.questId),
        )) {
      throw StateError('Missionの最新状態を確認できませんでした。');
    }
    return loaded;
  }

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
      if (!allowPending &&
          (ref.read(taskMutationControllerProvider).canRetry ||
              ref.read(taskMutationControllerProvider).canCleanup ||
              ref.read(taskMutationControllerProvider).needsConflictRefresh)) {
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
    return 'task-mutation:${const Uuid().v4()}';
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
          persist: !ref.read(taskRepositoryProvider).supportsAtomicCompletion,
        );
  }
}
