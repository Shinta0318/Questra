import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../core/config/supabase_config.dart';
import '../arc_memory/arc_memory_model.dart';
import '../arc_memory/arc_memory_providers.dart';
import '../auth/auth_controller.dart';
import 'arc_quest_guide_service.dart';
import 'quest_model.dart';

final arcQuestGuideServiceProvider = Provider<ArcQuestGuideService>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseArcQuestGuideService(client: Supabase.instance.client);
  }
  return const LocalArcQuestGuideService();
});

final arcQuestGuideControllerProvider =
    NotifierProvider<ArcQuestGuideController, ArcQuestGuideState>(
      ArcQuestGuideController.new,
    );

class ArcQuestGuideState {
  const ArcQuestGuideState({
    this.guidesByQuest = const {},
    this.loadingQuestIds = const {},
    this.errorsByQuest = const {},
  });

  final Map<String, ArcQuestGuide> guidesByQuest;
  final Set<String> loadingQuestIds;
  final Map<String, String> errorsByQuest;

  ArcQuestGuide? guideFor(String questId) => guidesByQuest[questId];

  bool isLoading(String questId) => loadingQuestIds.contains(questId);

  String? errorFor(String questId) => errorsByQuest[questId];

  ArcQuestGuideState copyWith({
    Map<String, ArcQuestGuide>? guidesByQuest,
    Set<String>? loadingQuestIds,
    Map<String, String>? errorsByQuest,
  }) {
    return ArcQuestGuideState(
      guidesByQuest: guidesByQuest ?? this.guidesByQuest,
      loadingQuestIds: loadingQuestIds ?? this.loadingQuestIds,
      errorsByQuest: errorsByQuest ?? this.errorsByQuest,
    );
  }
}

class ArcQuestGuideController extends Notifier<ArcQuestGuideState> {
  @override
  ArcQuestGuideState build() => const ArcQuestGuideState();

  Future<void> generateForQuest(Quest quest) async {
    if (state.isLoading(quest.id)) {
      return;
    }

    state = state.copyWith(
      loadingQuestIds: {...state.loadingQuestIds, quest.id},
      errorsByQuest: {...state.errorsByQuest}..remove(quest.id),
    );

    try {
      final guide = await ref
          .read(arcQuestGuideServiceProvider)
          .generate(quest: quest);
      state = state.copyWith(
        guidesByQuest: {...state.guidesByQuest, quest.id: guide},
        loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
      );
      unawaited(_rememberGuide(quest, guide));
    } catch (error) {
      state = state.copyWith(
        loadingQuestIds: {...state.loadingQuestIds}..remove(quest.id),
        errorsByQuest: {...state.errorsByQuest, quest.id: error.toString()},
      );
    }
  }

  Future<void> _rememberGuide(Quest quest, ArcQuestGuide guide) async {
    final userId = ref.read(authControllerProvider).profile?.id;
    if (userId == null) {
      return;
    }

    try {
      await ref
          .read(memoryExtractionServiceProvider)
          .extractAndSave(
            MemoryExtractionEvent(
              userId: userId,
              questId: quest.id,
              sourceId: quest.id,
              sourceType: ArcMemorySourceType.questUpdated,
              title: 'Arc Guide generated',
              text:
                  '${guide.summary}\n${guide.path}\n'
                  '${guide.missionCandidates.map((candidate) => candidate.title).join(' / ')}',
              metadata: {
                'source': guide.sourceType,
                'mission_candidate_count': guide.missionCandidates.length,
              },
            ),
          );
      ref.invalidate(visibleArcMemoriesProvider);
    } catch (_) {
      // Keep the generated guide available even if memory sync is unavailable.
    }
  }
}
