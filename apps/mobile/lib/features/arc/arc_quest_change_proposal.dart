enum ArcQuestChangeKind {
  addMission,
  addReference,
  reviewDeadline,
  deleteMission,
  splitMission,
  mergeMissions,
  reorderMission,
  addCaution,
  addEnterpriseSupport,
}

class ArcQuestChangeProposal {
  const ArcQuestChangeProposal({
    required this.id,
    required this.kind,
    required this.questId,
    required this.title,
    required this.description,
    required this.rationale,
    this.targetMissionId,
    this.referenceQuery,
    this.proposedTargetDate,
    this.groundingSources = const [],
  });

  final String id;
  final ArcQuestChangeKind kind;
  final String questId;
  final String title;
  final String description;
  final String rationale;
  final String? targetMissionId;
  final String? referenceQuery;
  final DateTime? proposedTargetDate;
  final List<ArcGroundingSource> groundingSources;

  bool get canApplyDirectly => switch (kind) {
        ArcQuestChangeKind.addMission ||
        ArcQuestChangeKind.addReference ||
        ArcQuestChangeKind.reviewDeadline =>
          true,
        _ => false,
      };

  String get actionLabel => switch (kind) {
        ArcQuestChangeKind.addMission => 'Missionを追加',
        ArcQuestChangeKind.addReference => '参考情報を追加',
        ArcQuestChangeKind.reviewDeadline => '期限を見直す',
        ArcQuestChangeKind.deleteMission => 'Missionを削除',
        ArcQuestChangeKind.splitMission => 'Missionを分割',
        ArcQuestChangeKind.mergeMissions => 'Missionを統合',
        ArcQuestChangeKind.reorderMission => '順番を変更',
        ArcQuestChangeKind.addCaution => '注意事項を追加',
        ArcQuestChangeKind.addEnterpriseSupport => '企業支援を追加',
      };
}

class ArcGroundingSource {
  const ArcGroundingSource({
    required this.title,
    required this.publisher,
    required this.url,
  });

  final String title;
  final String publisher;
  final Uri url;
}

ArcQuestChangeKind? arcQuestChangeKindFromStorage(String? value) {
  return switch (value) {
    'add_mission' => ArcQuestChangeKind.addMission,
    'add_reference' => ArcQuestChangeKind.addReference,
    'review_deadline' => ArcQuestChangeKind.reviewDeadline,
    'delete_mission' => ArcQuestChangeKind.deleteMission,
    'split_mission' => ArcQuestChangeKind.splitMission,
    'merge_missions' => ArcQuestChangeKind.mergeMissions,
    'reorder_mission' => ArcQuestChangeKind.reorderMission,
    'add_caution' => ArcQuestChangeKind.addCaution,
    'add_enterprise_support' => ArcQuestChangeKind.addEnterpriseSupport,
    _ => null,
  };
}
