import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/performance/performance_limits.dart';
import '../arc/arc_action_trigger_service.dart';
import '../arc/arc_bond_growth_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_guidance_providers.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../media/media_providers.dart';
import '../mission/mission_controller.dart';
import '../quest/quest_controller.dart';
import '../tagging/tagging_providers.dart';
import '../task/task_controller.dart';
import 'trail_model.dart';
import 'trail_pagination_state.dart';
import 'trail_parent_validator.dart';
import 'trail_providers.dart';
import 'trail_repository.dart';
import 'trail_sync_state.dart';

final trailControllerProvider = NotifierProvider<TrailController, List<Trail>>(
  TrailController.new,
);

final trailMediaControllerProvider =
    NotifierProvider<TrailMediaController, Map<String, MediaAttachment>>(
      TrailMediaController.new,
    );

enum TrailUpdateStatus { saved, rejected, failed }

class TrailUpdateResult {
  const TrailUpdateResult(this.status, {this.message});

  final TrailUpdateStatus status;
  final String? message;

  bool get isSaved => status == TrailUpdateStatus.saved;
}

class TrailController extends Notifier<List<Trail>> {
  int _loadGeneration = 0;
  TrailPageCursor? _nextCursor;

  @override
  List<Trail> build() {
    final initialUserId = ref.read(authControllerProvider).profile?.id;
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next == previous) return;
      _loadGeneration++;
      _nextCursor = null;
      state = const [];
      ref.read(trailPaginationControllerProvider.notifier).reset();
      if (next != null) unawaited(loadForUser(next));
    });

    if (initialUserId != null) {
      unawaited(Future<void>.microtask(() => loadForUser(initialUserId)));
    }

    return const [];
  }

  List<Trail> trailsForQuest(String questId) {
    return state
        .where((trail) => trail.questId == questId)
        .toList(growable: false);
  }

  Future<void> loadForUser(String userId) async {
    if (ref.read(authControllerProvider).profile?.id != userId) return;
    final generation = ++_loadGeneration;
    _nextCursor = null;
    final sync = ref.read(trailSyncControllerProvider.notifier);
    final pagination = ref.read(trailPaginationControllerProvider.notifier);
    pagination.reset();
    sync.loading('Trailを読み込んでいます...', TrailSyncOperation.load);
    try {
      final page = await ref
          .read(trailRepositoryProvider)
          .findByUser(
            userId,
            limit: QuestraPerformanceLimits.trailListLimit + 1,
          );
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != userId) {
        return;
      }
      final hasMore = page.length > QuestraPerformanceLimits.trailListLimit;
      final visiblePage = page
          .take(QuestraPerformanceLimits.trailListLimit)
          .toList(growable: false);
      state = visiblePage;
      _nextCursor = visiblePage.isEmpty
          ? null
          : TrailPageCursor.fromTrail(visiblePage.last);
      pagination.loaded(hasMore: hasMore);
      // Routine reads do not need a success banner. Empty and loaded states are
      // already visible in the Trail screen, while failures stay actionable.
      sync.clear();
    } catch (error) {
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != userId) {
        return;
      }
      pagination.reset();
      sync.failed(error);
    }
  }

  Future<void> loadMoreForUser(String userId) async {
    if (ref.read(authControllerProvider).profile?.id != userId) return;
    final paginationState = ref.read(trailPaginationControllerProvider);
    if (paginationState.isLoading || !paginationState.canRequestMore) return;
    final pagination = ref.read(trailPaginationControllerProvider.notifier);
    final generation = _loadGeneration;
    final cursor = _nextCursor;
    pagination.loading();
    try {
      final page = await ref
          .read(trailRepositoryProvider)
          .findByUser(
            userId,
            limit: QuestraPerformanceLimits.trailListLimit + 1,
            before: cursor,
          );
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != userId) {
        return;
      }
      final hasMore = page.length > QuestraPerformanceLimits.trailListLimit;
      final existingIds = state.map((trail) => trail.id).toSet();
      final consumedPage = page
          .take(QuestraPerformanceLimits.trailListLimit)
          .toList(growable: false);
      final additions = consumedPage.where(
        (trail) => existingIds.add(trail.id),
      );
      state = [...state, ...additions];
      if (consumedPage.isNotEmpty) {
        _nextCursor = TrailPageCursor.fromTrail(consumedPage.last);
      }
      pagination.loaded(hasMore: hasMore);
    } catch (_) {
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != userId) {
        return;
      }
      pagination.failed();
    }
  }

  Trail addQuestTrail({
    required String questId,
    String? missionId,
    required String questTitle,
  }) {
    final trail = Trail(
      questId: questId,
      missionId: missionId,
      title: '$questTitle のTrail',
      summary: 'Questを進める中で、新しい挑戦の記録を残した。',
      content: 'Arcと一緒に航路を確認し、次のMissionへ進むためのTrailを残した。',
      trailType: missionId == null
          ? TrailType.questRecord
          : TrailType.missionRecord,
    );
    state = [trail, ...state];
    _recordTrailEmotion(trail);
    _trackTrailPosted(trail, surface: 'quest');
    unawaited(_persistTrail(trail));
    return trail;
  }

  Trail addManualTrail({
    required String title,
    required String summary,
    required String content,
    String? trailId,
    TrailParentContext? parent,
  }) {
    final trail = _addManualTrailToState(
      title: title,
      summary: summary,
      content: content,
      trailId: trailId,
      parent: parent,
    );
    unawaited(_persistTrail(trail));
    return trail;
  }

  Future<bool> addManualTrailAndWait({
    required String title,
    required String summary,
    required String content,
    String? trailId,
    TrailParentContext? parent,
  }) async {
    final trail = _addManualTrailToState(
      title: title,
      summary: summary,
      content: content,
      trailId: trailId,
      parent: parent,
    );
    final saved = await _persistTrailWithResult(trail);
    if (!saved) {
      state = state.where((current) => current.id != trail.id).toList();
    }
    return saved;
  }

  Trail _addManualTrailToState({
    required String title,
    required String summary,
    required String content,
    String? trailId,
    TrailParentContext? parent,
  }) {
    if (parent != null && !parent.isStructurallyValid) {
      throw ArgumentError.value(parent, 'parent', 'Trail parent is invalid.');
    }
    if (parent != null) {
      final validation = const TrailParentValidator().validate(
        parent: parent,
        quests: ref.read(questControllerProvider),
        missions: ref.read(missionControllerProvider),
        tasks: ref.read(taskControllerProvider),
      );
      if (!validation.canProceed) {
        throw ArgumentError.value(parent, 'parent', validation.reason);
      }
    }
    final trail = Trail(
      id: trailId,
      questId: parent?.questId,
      missionId: parent?.missionId,
      taskId: parent?.taskId,
      title: title,
      summary: summary,
      content: content,
      trailType: parent?.missionId != null
          ? TrailType.missionRecord
          : parent != null
          ? TrailType.questRecord
          : TrailType.manualNote,
      sourceType: parent?.taskId != null ? 'task_trail' : 'manual',
    );
    state = [trail, ...state.where((current) => current.id != trail.id)];
    _recordTrailEmotion(trail);
    _trackTrailPosted(trail, surface: 'manual');
    return trail;
  }

  void updateTrail(Trail updatedTrail) {
    final previous = state
        .where((trail) => trail.id == updatedTrail.id)
        .firstOrNull;
    if (previous == null || !_canApplyTrailUpdate(previous, updatedTrail)) {
      return;
    }
    state = [
      for (final trail in state)
        if (trail.id == updatedTrail.id) updatedTrail else trail,
    ];
    _recordTrailEmotion(updatedTrail);
    unawaited(_persistTrail(updatedTrail));
  }

  Future<bool> updateTrailAndWait(Trail updatedTrail) async {
    final result = await updateTrailWithResult(updatedTrail);
    return result.isSaved;
  }

  Future<TrailUpdateResult> updateTrailWithResult(Trail updatedTrail) async {
    final previous = state
        .where((trail) => trail.id == updatedTrail.id)
        .firstOrNull;
    if (previous == null) {
      return const TrailUpdateResult(
        TrailUpdateStatus.rejected,
        message: 'このTrailは別の画面で変更された可能性があります。画面を更新してください。',
      );
    }
    if (!_canApplyTrailUpdate(previous, updatedTrail)) {
      return const TrailUpdateResult(
        TrailUpdateStatus.rejected,
        message: '紐づけ先を確認できませんでした。QuestとMissionを選び直してください。',
      );
    }
    state = [
      for (final trail in state)
        if (trail.id == updatedTrail.id) updatedTrail else trail,
    ];
    final saved = await _persistTrailWithResult(updatedTrail);
    if (saved) {
      _recordTrailEmotion(updatedTrail);
    } else {
      // Do not overwrite a newer local change or restore a removed Trail.
      state = [
        for (final trail in state)
          if (identical(trail, updatedTrail)) previous else trail,
      ];
    }
    return TrailUpdateResult(
      saved ? TrailUpdateStatus.saved : TrailUpdateStatus.failed,
      message: saved ? null : '保存できませんでした。入力を残したまま再試行できます。',
    );
  }

  bool _canApplyTrailUpdate(Trail previous, Trail updated) {
    return const TrailParentMutationPolicy().canApply(
      previous: previous,
      updated: updated,
      quests: ref.read(questControllerProvider),
      missions: ref.read(missionControllerProvider),
      tasks: ref.read(taskControllerProvider),
    );
  }

  void removeTrail(String trailId) {
    unawaited(removeTrailAndWait(trailId));
  }

  Future<bool> removeTrailAndWait(String trailId) async {
    final removedIndex = state.indexWhere((trail) => trail.id == trailId);
    if (removedIndex < 0) return false;
    final removedTrail = state[removedIndex];
    state = state.where((trail) => trail.id != trailId).toList();
    return _deleteTrail(trailId, removedTrail, removedIndex);
  }

  Future<MediaAttachment?> attachImageToTrail({
    required Trail trail,
    required XFile image,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(trailSyncControllerProvider.notifier)
          .failed('Trail画像を追加するにはログインが必要です。');
      return null;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trail画像をアップロードしています...', TrailSyncOperation.media);
    try {
      final attachment = await ref
          .read(mediaRepositoryProvider)
          .uploadTrailImage(
            ownerId: userId,
            trailId: trail.id,
            fileName: image.name,
            bytes: await image.readAsBytes(),
            contentType: image.mimeType ?? 'image/jpeg',
          );
      ref
          .read(trailMediaControllerProvider.notifier)
          .setAttachment(trail.id, attachment);
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .mediaAttached(
              userId: userId,
              mediaType: attachment.mediaType.storageKey,
              surface: 'trail',
            ),
      );
      sync.saved('Trailに画像を添付しました。');
      return attachment;
    } catch (error) {
      sync.failed(error);
      return null;
    }
  }

  Future<MediaAttachment?> replaceImageForTrail({
    required Trail trail,
    required MediaAttachment current,
    required XFile image,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(trailSyncControllerProvider.notifier)
          .failed('Trail画像を差し替えるにはログインが必要です。');
      return null;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trail画像を差し替えています...', TrailSyncOperation.media);
    try {
      final attachment = await ref
          .read(mediaRepositoryProvider)
          .replaceTrailImage(
            ownerId: userId,
            trailId: trail.id,
            current: current,
            fileName: image.name,
            bytes: await image.readAsBytes(),
            contentType: image.mimeType ?? 'image/jpeg',
          );
      ref
          .read(trailMediaControllerProvider.notifier)
          .setAttachment(trail.id, attachment);
      sync.saved('Trail画像を差し替えました。');
      return attachment;
    } catch (error) {
      sync.failed(error);
      return null;
    }
  }

  Future<bool> removeImageFromTrail({
    required Trail trail,
    required MediaAttachment attachment,
  }) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      ref
          .read(trailSyncControllerProvider.notifier)
          .failed('Trail画像を削除するにはログインが必要です。');
      return false;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trail画像を削除しています...', TrailSyncOperation.media);
    try {
      await ref
          .read(mediaRepositoryProvider)
          .deleteTrailImage(ownerId: userId, attachment: attachment);
      ref.read(trailMediaControllerProvider.notifier).clearAttachment(trail.id);
      sync.saved('Trail画像を削除しました。');
      return true;
    } catch (error) {
      sync.failed(error);
      return false;
    }
  }

  Future<void> _persistTrail(Trail trail) async {
    await _persistTrailWithResult(trail);
  }

  Future<bool> _persistTrailWithResult(Trail trail) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      final decision = ref
          .read(arcActionTriggerServiceProvider)
          .resolve(
            trigger: ArcActionTrigger.unauthenticated,
            trailTitle: trail.title,
            surface: 'Trail保存',
          );
      ref
          .read(arcEmotionTimelineControllerProvider.notifier)
          .record(
            emotion: decision.emotion,
            sourceType: decision.sourceType,
            reason: decision.message,
            sourceId: trail.id,
            questId: trail.questId,
            missionId: trail.missionId,
            trailId: trail.id,
          );
      return true;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trailを保存しています...', TrailSyncOperation.save);

    try {
      final savedTrail = await ref
          .read(trailRepositoryProvider)
          .save(ownerId: userId, trail: trail);
      if (ref.read(authControllerProvider).profile?.id != userId) return false;
      state = [
        for (final current in state)
          if (current.id == trail.id) savedTrail else current,
      ];
      unawaited(_tagTrail(userId, savedTrail));
      _growBond(savedTrail);
      unawaited(_rememberTrail(userId, savedTrail));
      sync.saved('Trailを保存しました。');
      return true;
    } catch (error) {
      sync.failed(error);
      final decision = ref
          .read(arcActionTriggerServiceProvider)
          .resolve(
            trigger: ArcActionTrigger.saveFailure,
            trailTitle: trail.title,
            surface: 'Trail保存',
          );
      ref
          .read(arcEmotionTimelineControllerProvider.notifier)
          .record(
            emotion: decision.emotion,
            sourceType: decision.sourceType,
            reason: decision.message,
            sourceId: trail.id,
            questId: trail.questId,
            missionId: trail.missionId,
            trailId: trail.id,
          );
      return false;
    }
  }

  void _trackTrailPosted(Trail trail, {required String surface}) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trailPosted(
            userId: ref.read(authControllerProvider).profile?.id,
            surface: surface,
            hasQuest: trail.questId != null,
            hasMission: trail.missionId != null,
          ),
    );
  }

  void _recordTrailEmotion(Trail trail) {
    final isReflection = trail.trailType == TrailType.arcReflection;
    final decision = ref
        .read(arcActionTriggerServiceProvider)
        .resolve(
          trigger: isReflection
              ? ArcActionTrigger.reflectionAdded
              : ArcActionTrigger.trailPosted,
          trailTitle: trail.title,
        );
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: decision.emotion,
          sourceType: decision.sourceType,
          reason: decision.message,
          sourceId: trail.id,
          questId: trail.questId,
          missionId: trail.missionId,
          trailId: trail.id,
        );
  }

  void _growBond(Trail trail) {
    final growth = ref.read(arcBondGrowthServiceProvider).forTrail(trail);
    final award = ref.read(stardustServiceProvider).forTrail(trail);
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .addBondScore(delta: growth.delta, reason: growth.reason),
    );
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .awardStardust(event: award.event, sourceId: trail.id),
    );
  }

  Future<void> _tagTrail(String userId, Trail trail) async {
    try {
      await ref
          .read(taggingServiceProvider)
          .tagTrail(ownerId: userId, trail: trail);
    } catch (_) {
      // Tagging is best-effort enrichment for future recommendations.
    }
  }

  Future<void> _rememberTrail(String userId, Trail trail) async {
    try {
      await ref
          .read(memoryExtractionServiceProvider)
          .extractAndSave(
            MemoryExtractionEvent(
              userId: userId,
              questId: trail.questId,
              missionId: trail.missionId,
              trailId: trail.id,
              sourceId: trail.id,
              sourceType: ArcMemorySourceType.trailPosted,
              title: 'Trailの記憶',
              text: '${trail.title}: ${trail.summary} ${trail.content}',
              metadata: {'trail_type': trail.trailType.storageKey},
            ),
          );
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Arc Memory sync state is introduced later; keep the Trail action.
    }
  }

  Future<bool> _deleteTrail(
    String trailId,
    Trail removedTrail,
    int removedIndex,
  ) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return true;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trailを削除しています...', TrailSyncOperation.delete);

    try {
      await ref
          .read(trailRepositoryProvider)
          .delete(ownerId: userId, trailId: trailId);
      if (ref.read(authControllerProvider).profile?.id == userId) {
        sync.saved('Trailを削除しました。');
      }
      return true;
    } catch (error) {
      if (ref.read(authControllerProvider).profile?.id != userId) return false;
      if (!state.any((trail) => trail.id == removedTrail.id)) {
        final restored = [...state];
        restored.insert(removedIndex.clamp(0, restored.length), removedTrail);
        state = restored;
      }
      sync.failed(error);
      return false;
    }
  }
}

class TrailMediaController extends Notifier<Map<String, MediaAttachment>> {
  int _loadGeneration = 0;

  @override
  Map<String, MediaAttachment> build() {
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != previous) {
        _loadGeneration++;
        state = const {};
        if (next != null) _loadForCurrentTrails();
      }
    });

    ref.listen(trailControllerProvider, (previous, next) {
      if (ref.read(authControllerProvider).profile != null) {
        loadForTrails(next);
      }
    });

    if (ref.read(authControllerProvider).profile != null) {
      unawaited(Future<void>.microtask(_loadForCurrentTrails));
    }

    return const {};
  }

  void setAttachment(String trailId, MediaAttachment attachment) {
    _loadGeneration++;
    state = {...state, trailId: attachment};
  }

  void clearAttachment(String trailId) {
    _loadGeneration++;
    final updated = {...state}..remove(trailId);
    state = updated;
  }

  Future<void> loadForTrails(List<Trail> trails) async {
    final generation = ++_loadGeneration;
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null || trails.isEmpty) {
      state = const {};
      return;
    }
    final trailIds = trails.map((trail) => trail.id).toSet();
    final preserved = <String, MediaAttachment>{
      for (final entry in state.entries)
        if (trailIds.contains(entry.key)) entry.key: entry.value,
    };
    final missingIds = trailIds.difference(preserved.keys.toSet()).toList();
    if (missingIds.isEmpty) {
      state = preserved;
      return;
    }
    try {
      final loaded = await ref
          .read(mediaRepositoryProvider)
          .findTrailImageMap(ownerId: userId, trailIds: missingIds);
      if (generation != _loadGeneration ||
          ref.read(authControllerProvider).profile?.id != userId) {
        return;
      }
      state = {...preserved, ...loaded};
    } catch (_) {
      if (generation == _loadGeneration &&
          ref.read(authControllerProvider).profile?.id == userId) {
        state = preserved;
      }
    }
  }

  void _loadForCurrentTrails() {
    unawaited(loadForTrails(ref.read(trailControllerProvider)));
  }
}
