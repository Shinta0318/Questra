import '../mission/mission_model.dart';
import '../quest/quest_dna_snapshot.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

enum ChallengeGraphNodeType { quest, mission, trail, theme, interest }

enum ChallengeGraphInsightType { missionGap, trailGap, reflectionGap, steady }

class ChallengeGraphNode {
  const ChallengeGraphNode({
    required this.id,
    required this.label,
    required this.type,
  });

  final String id;
  final String label;
  final ChallengeGraphNodeType type;
}

class ChallengeGraphEdge {
  const ChallengeGraphEdge({
    required this.fromId,
    required this.toId,
    required this.relationship,
  });

  final String fromId;
  final String toId;
  final String relationship;
}

class ChallengeGraphPreview {
  const ChallengeGraphPreview({required this.nodes, required this.edges});

  final List<ChallengeGraphNode> nodes;
  final List<ChallengeGraphEdge> edges;

  int countNodes(ChallengeGraphNodeType type) {
    return nodes.where((node) => node.type == type).length;
  }
}

class ChallengeGraphInsight {
  const ChallengeGraphInsight({
    required this.type,
    required this.title,
    required this.message,
    required this.suggestedAction,
    required this.priority,
  });

  final ChallengeGraphInsightType type;
  final String title;
  final String message;
  final String suggestedAction;
  final int priority;
}

class ChallengeGraphPreviewService {
  const ChallengeGraphPreviewService();

  ChallengeGraphPreview buildForQuest({
    required Quest quest,
    required List<Mission> missions,
    required List<Trail> trails,
  }) {
    final snapshot = const QuestDnaSnapshotResolver().resolve(quest);
    final nodes = <ChallengeGraphNode>[
      ChallengeGraphNode(
        id: 'quest:${quest.id}',
        label: quest.title,
        type: ChallengeGraphNodeType.quest,
      ),
    ];
    final edges = <ChallengeGraphEdge>[];

    final theme = snapshot.attributes.firstWhere(
      (attribute) => attribute.key == 'theme',
    );
    final category = snapshot.attributes.firstWhere(
      (attribute) => attribute.key == 'category',
    );
    _addContextNode(
      nodes: nodes,
      edges: edges,
      quest: quest,
      id: 'theme:${theme.value}',
      label: theme.value,
      type: ChallengeGraphNodeType.theme,
      relationship: 'has_theme',
    );
    _addContextNode(
      nodes: nodes,
      edges: edges,
      quest: quest,
      id: 'interest:${category.value}',
      label: category.value,
      type: ChallengeGraphNodeType.interest,
      relationship: 'has_interest',
    );

    for (final mission in missions.where(
      (mission) => mission.questId == quest.id,
    )) {
      nodes.add(
        ChallengeGraphNode(
          id: 'mission:${mission.id}',
          label: mission.title,
          type: ChallengeGraphNodeType.mission,
        ),
      );
      edges.add(
        ChallengeGraphEdge(
          fromId: 'quest:${quest.id}',
          toId: 'mission:${mission.id}',
          relationship: 'contains_mission',
        ),
      );
    }

    for (final trail in trails.where((trail) => trail.questId == quest.id)) {
      nodes.add(
        ChallengeGraphNode(
          id: 'trail:${trail.id}',
          label: trail.title,
          type: ChallengeGraphNodeType.trail,
        ),
      );
      edges.add(
        ChallengeGraphEdge(
          fromId: 'quest:${quest.id}',
          toId: 'trail:${trail.id}',
          relationship: 'has_trail',
        ),
      );
      final missionId = trail.missionId;
      if (missionId != null) {
        edges.add(
          ChallengeGraphEdge(
            fromId: 'mission:$missionId',
            toId: 'trail:${trail.id}',
            relationship: 'produces_trail',
          ),
        );
      }
    }

    return ChallengeGraphPreview(
      nodes: List.unmodifiable(nodes),
      edges: List.unmodifiable(edges),
    );
  }

  List<ChallengeGraphInsight> insightsForQuest({
    required Quest quest,
    required List<Mission> missions,
    required List<Trail> trails,
  }) {
    final relatedMissions = missions
        .where((mission) => mission.questId == quest.id)
        .toList(growable: false);
    final relatedTrails = trails
        .where((trail) => trail.questId == quest.id)
        .toList(growable: false);
    final reflectionTrails = relatedTrails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .toList(growable: false);
    final insights = <ChallengeGraphInsight>[];

    if (relatedMissions.isEmpty) {
      insights.add(
        const ChallengeGraphInsight(
          type: ChallengeGraphInsightType.missionGap,
          title: 'Missionの星を足す',
          message: 'このQuestには、まだ具体的な一歩が結ばれていません。',
          suggestedAction: 'Arc Guideから最初のMissionを3つ作る',
          priority: 90,
        ),
      );
    }

    if (relatedMissions.isNotEmpty && relatedTrails.isEmpty) {
      insights.add(
        const ChallengeGraphInsight(
          type: ChallengeGraphInsightType.trailGap,
          title: 'Trailを残す',
          message: 'Missionは見えています。次は進んだ証をTrailとして残せます。',
          suggestedAction: '今日進めたことを短いTrailにする',
          priority: 76,
        ),
      );
    }

    if (relatedTrails.length >= 2 && reflectionTrails.isEmpty) {
      insights.add(
        const ChallengeGraphInsight(
          type: ChallengeGraphInsightType.reflectionGap,
          title: 'Reflectionで意味を拾う',
          message: 'Trailが育っています。振り返ると、次の航路が見えやすくなります。',
          suggestedAction: '最近のTrailをArcと一緒に振り返る',
          priority: 68,
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        ChallengeGraphInsight(
          type: ChallengeGraphInsightType.steady,
          title: '航路はつながっています',
          message: 'Quest、Mission、Trailがつながり、星図の輪郭が見えています。',
          suggestedAction: quest.progress >= 0.8
              ? '達成前の最後のTrailを残す'
              : '次のMissionを一つ進める',
          priority: 50,
        ),
      );
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(insights.take(3));
  }

  void _addContextNode({
    required List<ChallengeGraphNode> nodes,
    required List<ChallengeGraphEdge> edges,
    required Quest quest,
    required String id,
    required String label,
    required ChallengeGraphNodeType type,
    required String relationship,
  }) {
    nodes.add(ChallengeGraphNode(id: id, label: label, type: type));
    edges.add(
      ChallengeGraphEdge(
        fromId: 'quest:${quest.id}',
        toId: id,
        relationship: relationship,
      ),
    );
  }
}
