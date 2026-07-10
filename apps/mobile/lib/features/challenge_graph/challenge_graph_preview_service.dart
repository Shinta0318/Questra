import '../mission/mission_model.dart';
import '../quest/quest_dna_snapshot.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

enum ChallengeGraphNodeType { quest, mission, trail, theme, interest }

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
