import 'quest_model.dart';

class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.difficulty,
    required this.milestones,
    required this.missions,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final QuestDifficulty difficulty;
  final List<QuestTemplateMilestone> milestones;
  final List<QuestTemplateMission> missions;
}

class QuestTemplateMilestone {
  const QuestTemplateMilestone({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class QuestTemplateMission {
  const QuestTemplateMission({required this.title, required this.description});

  final String title;
  final String description;
}
