import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

class ArcJourneyContext {
  const ArcJourneyContext({
    required this.activeQuestCount,
    required this.trailCount,
    required this.guidance,
    this.focusQuestTitle,
    this.latestTrailTitle,
  });

  final int activeQuestCount;
  final int trailCount;
  final String guidance;
  final String? focusQuestTitle;
  final String? latestTrailTitle;

  factory ArcJourneyContext.fromJourney({
    required List<Quest> quests,
    required List<Trail> trails,
  }) {
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));
    final latestTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final focusQuest = activeQuests.firstOrNull;
    final latestTrail = latestTrails.firstOrNull;

    return ArcJourneyContext(
      activeQuestCount: activeQuests.length,
      trailCount: trails.length,
      focusQuestTitle: focusQuest?.title,
      latestTrailTitle: latestTrail?.title,
      guidance: _buildGuidance(focusQuest, latestTrail, activeQuests.length),
    );
  }

  static String _buildGuidance(
    Quest? focusQuest,
    Trail? latestTrail,
    int activeQuestCount,
  ) {
    if (focusQuest != null && latestTrail != null) {
      return 'I can see ${focusQuest.title} moving through your latest Trail: ${latestTrail.title}. Choose the next small Mission and keep the record warm.';
    }

    if (focusQuest != null) {
      return 'Your strongest active Quest is ${focusQuest.title}. Leave one Trail when you take the next visible step.';
    }

    if (latestTrail != null) {
      return 'Your latest Trail is ${latestTrail.title}. Turn that memory into the next Quest when you are ready.';
    }

    if (activeQuestCount == 0) {
      return 'The journey is quiet. Start with one Quest, then I can help you shape the next step.';
    }

    return 'I am reading your Quest and Trail context. The next useful step is the one you can record today.';
  }
}
