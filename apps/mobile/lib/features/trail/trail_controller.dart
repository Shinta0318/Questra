import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import '../media/media_model.dart';
import '../media/media_providers.dart';
import 'trail_model.dart';
import 'trail_providers.dart';
import 'trail_sync_state.dart';

final trailControllerProvider = NotifierProvider<TrailController, List<Trail>>(
  TrailController.new,
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
      if (trails.isNotEmpty) {
        state = trails;
      }
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
    unawaited(_persistTrail(trail));
    return trail;
  }

  void updateTrail(Trail updatedTrail) {
    state = [
      for (final trail in state)
        if (trail.id == updatedTrail.id) updatedTrail else trail,
    ];
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
      sync.saved('Trail image attached.');
      return attachment;
    } catch (error) {
      sync.failed(error);
      return null;
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
      unawaited(_rememberTrail(userId, savedTrail));
      sync.saved('Trail record saved.');
    } catch (error) {
      sync.failed(error);
    }
  }

  Future<void> _rememberTrail(String userId, Trail trail) async {
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
