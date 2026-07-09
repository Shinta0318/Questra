import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum DreamBoardItemType { vision, reference, tool, guild, generatedBackground }

class DreamBoardItem {
  DreamBoardItem({
    String? id,
    required this.questId,
    required this.title,
    required this.note,
    required this.itemType,
    this.imageUrl,
    this.sourceUrl,
    this.metadata = const {},
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String questId;
  final String title;
  final String note;
  final DreamBoardItemType itemType;
  final String? imageUrl;
  final String? sourceUrl;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
}

extension DreamBoardItemTypeLabel on DreamBoardItemType {
  String get label {
    return switch (this) {
      DreamBoardItemType.vision => '理想イメージ',
      DreamBoardItemType.reference => '参考素材',
      DreamBoardItemType.tool => '必要な道具',
      DreamBoardItemType.guild => 'Guildの手がかり',
      DreamBoardItemType.generatedBackground => '背景候補',
    };
  }

  String get storageKey {
    return switch (this) {
      DreamBoardItemType.vision => 'vision',
      DreamBoardItemType.reference => 'reference',
      DreamBoardItemType.tool => 'tool',
      DreamBoardItemType.guild => 'guild',
      DreamBoardItemType.generatedBackground => 'generated_background',
    };
  }
}

DreamBoardItemType dreamBoardItemTypeFromStorage(String value) {
  return DreamBoardItemType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => DreamBoardItemType.reference,
  );
}
