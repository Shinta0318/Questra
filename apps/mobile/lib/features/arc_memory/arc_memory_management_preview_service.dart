import 'arc_memory_model.dart';

enum ArcMemoryManagementAction { review, delete, sensitivity, export }

class ArcMemoryManagementItem {
  const ArcMemoryManagementItem({
    required this.action,
    required this.title,
    required this.summary,
    required this.statusLabel,
  });

  final ArcMemoryManagementAction action;
  final String title;
  final String summary;
  final String statusLabel;
}

class ArcMemoryTypePreview {
  const ArcMemoryTypePreview({
    required this.type,
    required this.label,
    required this.description,
  });

  final ArcMemoryType type;
  final String label;
  final String description;
}

class ArcMemoryManagementPreview {
  const ArcMemoryManagementPreview({
    required this.heading,
    required this.summary,
    required this.typePreviews,
    required this.actions,
  });

  final String heading;
  final String summary;
  final List<ArcMemoryTypePreview> typePreviews;
  final List<ArcMemoryManagementItem> actions;
}

class ArcMemoryManagementPreviewService {
  const ArcMemoryManagementPreviewService();

  ArcMemoryManagementPreview buildPreview() {
    return const ArcMemoryManagementPreview(
      heading: 'Arc Memory管理プレビュー',
      summary:
          'Arc Memoryは、Arcが君の旅路を覚えておくための記憶です。Betaでは確認できる範囲を広げ、削除や感度管理へつながる導線を段階的に整えます。',
      typePreviews: [
        ArcMemoryTypePreview(
          type: ArcMemoryType.questMemory,
          label: 'Quest Memory',
          description: 'Questの目的、進捗、転機',
        ),
        ArcMemoryTypePreview(
          type: ArcMemoryType.missionMemory,
          label: 'Mission Memory',
          description: '小さな一歩と完了の記録',
        ),
        ArcMemoryTypePreview(
          type: ArcMemoryType.trailMemory,
          label: 'Trail Memory',
          description: '挑戦の記録と振り返り',
        ),
        ArcMemoryTypePreview(
          type: ArcMemoryType.arcRelationshipMemory,
          label: 'Bond Memory',
          description: 'Arcとの関係性の変化',
        ),
        ArcMemoryTypePreview(
          type: ArcMemoryType.emotionalMemory,
          label: 'Emotion Memory',
          description: '不安、喜び、再挑戦の兆し',
        ),
      ],
      actions: [
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.review,
          title: '記憶を確認',
          summary: 'Arcが参照する記憶を、ユーザーが読める形で表示する。',
          statusLabel: 'Preview',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.delete,
          title: '記憶を削除',
          summary: '不要な記憶を本人の操作で消せるようにする。',
          statusLabel: 'Planned',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.sensitivity,
          title: '感度を見直す',
          summary: 'Personal / Sensitiveな記憶を区別して扱う。',
          statusLabel: 'Planned',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.export,
          title: 'エクスポート',
          summary: '将来、本人の記憶データを取り出せるようにする。',
          statusLabel: 'Future',
        ),
      ],
    );
  }
}
