import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/analytics/analytics_service.dart';
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
import '../tagging/tagging_providers.dart';
import 'trail_model.dart';
import 'trail_providers.dart';
import 'trail_sync_state.dart';

final trailControllerProvider = NotifierProvider<TrailController, List<Trail>>(
  TrailController.new,
);

final trailMediaControllerProvider =
    NotifierProvider<TrailMediaController, Map<String, MediaAttachment>>(
      TrailMediaController.new,
    );

class TrailController extends Notifier<List<Trail>> {
  @override
  List<Trail> build() {
    final initialUserId = ref.read(authControllerProvider).profile?.id;
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next == previous) return;
      state = const [];
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
    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trailを読み込んでいます...');
    try {
      final trails = await ref.read(trailRepositoryProvider).findByUser(userId);
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      state = trails;
      sync.saved('Trailを読み込みました。');
    } catch (error) {
      if (ref.read(authControllerProvider).profile?.id != userId) return;
      sync.failed(error);
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
    state = [
      for (final trail in state)
        if (trail.id == updatedTrail.id) updatedTrail else trail,
    ];
    _recordTrailEmotion(updatedTrail);
    unawaited(_persistTrail(updatedTrail));
  }

  void removeTrail(String trailId) {
    final removedTrail = state
        .where((trail) => trail.id == trailId)
        .firstOrNull;
    state = state.where((trail) => trail.id != trailId).toList();
    unawaited(_deleteTrail(trailId, removedTrail));
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
    sync.loading('Trail画像をアップロードしています...');
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
    sync.loading('Trail画像を差し替えています...');
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
    sync.loading('Trail画像を削除しています...');
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
    sync.loading('Trailを保存しています...');

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

  Future<void> _deleteTrail(String trailId, Trail? removedTrail) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Trailを削除しています...');

    try {
      await ref
          .read(trailRepositoryProvider)
          .delete(ownerId: userId, trailId: trailId);
      sync.saved('Trailを削除しました。');
    } catch (error) {
      if (removedTrail != null) {
        state = [removedTrail, ...state];
      }
      sync.failed(error);
    }
  }
}

class TrailMediaController extends Notifier<Map<String, MediaAttachment>> {
  @override
  Map<String, MediaAttachment> build() {
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next == null) {
        state = const {};
        return;
      }
      if (next != previous) {
        _loadForCurrentTrails();
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
    state = {...state, trailId: attachment};
  }

  void clearAttachment(String trailId) {
    final updated = {...state}..remove(trailId);
    state = updated;
  }

  Future<void> loadForTrails(List<Trail> trails) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null || trails.isEmpty) {
      state = const {};
      return;
    }

    final nextState = <String, MediaAttachment>{};
    for (final trail in trails) {
      try {
        final images = await ref
            .read(mediaRepositoryProvider)
            .findTrailImages(ownerId: userId, trailId: trail.id);
        if (images.isNotEmpty) {
          nextState[trail.id] = images.first;
        }
      } catch (_) {
        // Media sync state is introduced later; keep loading best-effort.
      }
    }
    state = nextState;
  }

  void _loadForCurrentTrails() {
    unawaited(loadForTrails(ref.read(trailControllerProvider)));
  }
}
