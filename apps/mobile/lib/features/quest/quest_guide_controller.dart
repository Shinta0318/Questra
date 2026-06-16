import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'arc_advice_providers.dart';
import 'quest_decomposition_service.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';
import 'quest_providers.dart';

final questDecompositionServiceProvider = Provider<QuestDecompositionService>(
  (ref) => const QuestDecompositionService(),
);

final questGuideControllerProvider =
    NotifierProvider<QuestGuideController, QuestGuideState>(
      QuestGuideController.new,
    );

class QuestGuideState {
  const QuestGuideState({
    this.guidesByQuest = const {},
    this.adviceByQuest = const {},
    this.starMapByQuest = const {},
  });

  final Map<String, List<QuestGuide>> guidesByQuest;
  final Map<String, List<ArcAdvice>> adviceByQuest;
  final Map<String, List<StarMapItem>> starMapByQuest;

  QuestGuideState copyWith({
    Map<String, List<QuestGuide>>? guidesByQuest,
    Map<String, List<ArcAdvice>>? adviceByQuest,
    Map<String, List<StarMapItem>>? starMapByQuest,
  }) {
    return QuestGuideState(
      guidesByQuest: guidesByQuest ?? this.guidesByQuest,
      adviceByQuest: adviceByQuest ?? this.adviceByQuest,
      starMapByQuest: starMapByQuest ?? this.starMapByQuest,
    );
  }
}

class QuestGuideController extends Notifier<QuestGuideState> {
  @override
  QuestGuideState build() => const QuestGuideState();

  List<QuestGuide> guidesForQuest(String questId) {
    return state.guidesByQuest[questId] ?? const [];
  }

  List<ArcAdvice> adviceForQuest(String questId) {
    return state.adviceByQuest[questId] ?? const [];
  }

  List<StarMapItem> starMapForQuest(String questId) {
    return state.starMapByQuest[questId] ?? const [];
  }

  void generateForQuest(Quest quest) {
    final bundle = ref
        .read(questDecompositionServiceProvider)
        .generateForQuest(quest);

    state = state.copyWith(
      guidesByQuest: {...state.guidesByQuest, quest.id: bundle.guides},
      adviceByQuest: {...state.adviceByQuest, quest.id: bundle.advice},
      starMapByQuest: {...state.starMapByQuest, quest.id: bundle.starMap},
    );
    unawaited(_persistGuides(quest.id, bundle.guides));
    unawaited(_refreshAdvice(quest, bundle.guides));
  }

  Future<void> loadGuidesForQuest(String questId) async {
    final guides = await ref
        .read(questGuideRepositoryProvider)
        .findByQuest(questId);
    if (guides.isNotEmpty) {
      state = state.copyWith(
        guidesByQuest: {...state.guidesByQuest, questId: guides},
      );
    }
  }

  Future<void> _persistGuides(String questId, List<QuestGuide> guides) async {
    try {
      final savedGuides = await ref
          .read(questGuideRepositoryProvider)
          .saveAll(guides);
      state = state.copyWith(
        guidesByQuest: {...state.guidesByQuest, questId: savedGuides},
      );
    } catch (_) {
      // Guide sync state is introduced later; keep generated local guides.
    }
  }

  Future<void> _refreshAdvice(Quest quest, List<QuestGuide> guides) async {
    final service = ref.read(arcAdviceServiceProvider);
    final advice = <ArcAdvice>[];
    for (final guide in guides) {
      advice.add(await service.generate(quest: quest, guide: guide));
    }

    state = state.copyWith(
      adviceByQuest: {...state.adviceByQuest, quest.id: advice},
    );
  }
}
