import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quest_decomposition_service.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

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
  }
}
