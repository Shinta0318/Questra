import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../auth/auth_controller.dart';
import 'arc_emotion_timeline_model.dart';
import 'arc_emotion_timeline_repository.dart';

final arcEmotionTimelineRepositoryProvider =
    Provider<ArcEmotionTimelineRepository>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseArcEmotionTimelineRepository(Supabase.instance.client);
      }
      return InMemoryArcEmotionTimelineRepository();
    });

final arcEmotionTimelineControllerProvider =
    NotifierProvider<ArcEmotionTimelineController, List<ArcEmotionEvent>>(
      ArcEmotionTimelineController.new,
    );

class ArcEmotionTimelineController extends Notifier<List<ArcEmotionEvent>> {
  static const localOwnerId = 'local-arc-emotion-timeline';

  @override
  List<ArcEmotionEvent> build() {
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        unawaited(loadForUser(next));
      }
    });

    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId != null) {
      unawaited(Future<void>.microtask(() => loadForUser(userId)));
    }

    return const [];
  }

  Future<void> loadForUser(String userId) async {
    try {
      state = await ref
          .read(arcEmotionTimelineRepositoryProvider)
          .findByUser(userId);
    } catch (_) {
      // Timeline is a companion surface; keep the main journey intact.
    }
  }

  ArcEmotionEvent record({
    required ArcEmotion emotion,
    required ArcEmotionSourceType sourceType,
    required String reason,
    String? sourceId,
    String? questId,
    String? missionId,
    String? trailId,
  }) {
    final event = ArcEmotionEvent(
      emotion: emotion,
      sourceType: sourceType,
      reason: reason,
      sourceId: sourceId,
      questId: questId,
      missionId: missionId,
      trailId: trailId,
    );
    state = [event, ...state].take(20).toList(growable: false);

    final ownerId =
        ref.read(authControllerProvider).profile?.id ?? localOwnerId;
    unawaited(_persist(ownerId, event));
    return event;
  }

  Future<void> _persist(String ownerId, ArcEmotionEvent event) async {
    try {
      await ref
          .read(arcEmotionTimelineRepositoryProvider)
          .save(ownerId: ownerId, event: event);
    } catch (_) {
      // Local state already records the moment; persistence can catch up later.
    }
  }
}
