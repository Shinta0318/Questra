enum GuildDiscoveryVisibility { private, unlisted, public }

enum GuildDiscoveryModerationStatus { pending, approved, rejected }

enum GuildDiscoverySection {
  recommended,
  trending,
  recent,
  seekingCompanions,
  missionLibrary,
}

class GuildDiscoveryQuest {
  const GuildDiscoveryQuest({
    required this.id,
    required this.title,
    required this.summary,
    required this.authorDisplayName,
    required this.tags,
    required this.difficultyScore,
    required this.publishedAt,
    this.visibility = GuildDiscoveryVisibility.private,
    this.moderationStatus = GuildDiscoveryModerationStatus.pending,
    this.estimatedDurationDays,
    this.estimatedCostLabel,
    this.copyCount = 0,
    this.completionCount = 0,
    this.averageCompletionRate = 0,
    this.reviewScore,
    this.reviewCount = 0,
    this.seekingCompanions = false,
    this.participantCount = 0,
  });

  final String id;
  final String title;
  final String summary;
  final String authorDisplayName;
  final List<String> tags;
  final int difficultyScore;
  final DateTime publishedAt;
  final GuildDiscoveryVisibility visibility;
  final GuildDiscoveryModerationStatus moderationStatus;
  final int? estimatedDurationDays;
  final String? estimatedCostLabel;
  final int copyCount;
  final int completionCount;
  final double averageCompletionRate;
  final double? reviewScore;
  final int reviewCount;
  final bool seekingCompanions;
  final int participantCount;

  bool get canAppearInDiscovery =>
      visibility == GuildDiscoveryVisibility.public &&
      moderationStatus == GuildDiscoveryModerationStatus.approved;
}

class GuildDiscoveryMission {
  const GuildDiscoveryMission({
    required this.id,
    required this.questPublicationId,
    required this.title,
    required this.purpose,
    required this.orderIndex,
    this.estimatedDurationDays,
    this.difficultyScore,
    this.tags = const <String>[],
    this.isPublished = false,
  });

  final String id;
  final String questPublicationId;
  final String title;
  final String purpose;
  final int orderIndex;
  final int? estimatedDurationDays;
  final int? difficultyScore;
  final List<String> tags;
  final bool isPublished;
}

class GuildDiscoveryProfile {
  const GuildDiscoveryProfile({
    this.preferredTags = const <String>[],
    this.preferredDifficulty,
  });

  final List<String> preferredTags;
  final int? preferredDifficulty;
}

class GuildDiscoveryResult {
  const GuildDiscoveryResult({
    required this.quest,
    required this.score,
    required this.reason,
  });

  final GuildDiscoveryQuest quest;
  final double score;
  final String reason;
}

class GuildQuestCopyOptions {
  const GuildQuestCopyOptions({
    this.includeMissions = true,
    this.optimizeWithArc = true,
    this.openEditorAfterCopy = true,
  });

  final bool includeMissions;
  final bool optimizeWithArc;
  final bool openEditorAfterCopy;
}
