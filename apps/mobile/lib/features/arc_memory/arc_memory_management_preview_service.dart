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
      heading: 'Arc Memory',
      summary: 'Arcが旅路に使う記憶を確認し、いつでも訂正・削除・無効化できます。',
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
          type: ArcMemoryType.taskMemory,
          label: 'Task Memory',
          description: '開始、完了、延期した具体的な行動',
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
          statusLabel: '確認する',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.delete,
          title: '記憶を削除',
          summary: '不要な記憶を本人の操作で消せるようにする。',
          statusLabel: '利用可能',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.sensitivity,
          title: '感度を見直す',
          summary: '個人情報を含む記憶を区別し、機微情報は保存しない。',
          statusLabel: '確認可能',
        ),
        ArcMemoryManagementItem(
          action: ArcMemoryManagementAction.export,
          title: 'エクスポート',
          summary: '将来、本人の記憶データを取り出せるようにする。',
          statusLabel: '今後対応',
        ),
      ],
    );
  }
}
