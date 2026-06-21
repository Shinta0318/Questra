import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../arc/arc_bond_growth_service.dart';
import '../arc/arc_emotion_timeline_controller.dart';
import '../arc/arc_emotion_timeline_model.dart';
import '../arc/stardust_service.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../media/media_providers.dart';
import '../tagging/tagging_providers.dart';
import '../../widgets/arc/arc_emotion.dart';
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
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        loadForUser(next);
      }
    });

    return [
      Trail(
        questId: 'mock-quest-arc',
        title: 'Arcと最初の航路を描いた',
        summary: 'Questを6つのGuideへ分解し、Missionの入口を見つけた。',
        content: 'Questの輪郭がぼんやりしていたが、航路・知識・鍛錬・仲間・準備・機会に分けると次の一歩が見えた。',
        trailType: TrailType.questRecord,
      ),
      Trail(
        questId: 'mock-quest-arc',
        missionId: 'mock-mission-first-step',
        title: '今日のMissionを1つ完了',
        summary: '5分でできる小さな行動を完了した。',
        content: '完了したMissionはTrailとして残り、次のQuest判断に使える。',
        trailType: TrailType.missionRecord,
      ),
    ];
  }

  List<Trail> trailsForQuest(String questId) {
    return state
        .where((trail) => trail.questId == questId)
        .toList(growable: false);
  }

  Future<void> loadForUser(String userId) async {
    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Loading Trail records...');
    try {
      final trails = await ref.read(trailRepositoryProvider).findByUser(userId);
      state = trails;
      sync.saved('Trail records loaded.');
    } catch (error) {
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
    unawaited(_persistTrail(trail));
    return trail;
  }

  Trail addManualTrail({
    required String title,
    required String summary,
    required String content,
  }) {
    final trail = Trail(
      title: title,
      summary: summary,
      content: content,
      trailType: TrailType.manualNote,
      sourceType: 'manual',
    );
    state = [trail, ...state];
    _recordTrailEmotion(trail);
    unawaited(_persistTrail(trail));
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
          .failed('Login is required to attach Trail media.');
      return null;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Uploading Trail image...');
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
      sync.saved('Trail image attached.');
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
          .failed('Login is required to replace Trail media.');
      return null;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Replacing Trail image...');
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
      sync.saved('Trail image replaced.');
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
          .failed('Login is required to remove Trail media.');
      return false;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Removing Trail image...');
    try {
      await ref
          .read(mediaRepositoryProvider)
          .deleteTrailImage(ownerId: userId, attachment: attachment);
      ref.read(trailMediaControllerProvider.notifier).clearAttachment(trail.id);
      sync.saved('Trail image removed.');
      return true;
    } catch (error) {
      sync.failed(error);
      return false;
    }
  }

  Future<void> _persistTrail(Trail trail) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    final sync = ref.read(trailSyncControllerProvider.notifier);
    sync.loading('Saving Trail record...');

    try {
      final savedTrail = await ref
          .read(trailRepositoryProvider)
          .save(ownerId: userId, trail: trail);
      state = [
        for (final current in state)
          if (current.id == trail.id) savedTrail else current,
      ];
      unawaited(_tagTrail(userId, savedTrail));
      _growBond(savedTrail);
      unawaited(_rememberTrail(userId, savedTrail));
      sync.saved('Trail record saved.');
    } catch (error) {
      sync.failed(error);
      ref
          .read(arcEmotionTimelineControllerProvider.notifier)
          .record(
            emotion: ArcEmotion.worried,
            sourceType: ArcEmotionSourceType.saveFailure,
            reason: 'Trail「${trail.title}」の保存で星図が少し揺れました。',
            sourceId: trail.id,
            questId: trail.questId,
            missionId: trail.missionId,
            trailId: trail.id,
          );
    }
  }

  void _recordTrailEmotion(Trail trail) {
    final isReflection = trail.trailType == TrailType.arcReflection;
    ref
        .read(arcEmotionTimelineControllerProvider.notifier)
        .record(
          emotion: isReflection ? ArcEmotion.support : ArcEmotion.celebrate,
          sourceType: isReflection
              ? ArcEmotionSourceType.reflectionAdded
              : ArcEmotionSourceType.trailPosted,
          reason: isReflection
              ? 'Trail「${trail.title}」から振り返りの星が見つかりました。'
              : 'Trail「${trail.title}」が航路に残りました。',
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
          .addStardust(amount: award.amount, reason: award.reason),
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
              title: 'Trail memory',
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
    sync.loading('Deleting Trail record...');

    try {
      await ref
          .read(trailRepositoryProvider)
          .delete(ownerId: userId, trailId: trailId);
      sync.saved('Trail record deleted.');
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
