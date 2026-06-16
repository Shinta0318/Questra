import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MediaType { image, video, audio, document }

class MediaAttachment {
  MediaAttachment({
    String? id,
    required this.ownerId,
    this.guildId,
    required this.bucket,
    required this.path,
    required this.mediaType,
    this.relatedTable,
    this.relatedId,
    this.visibility = 'private',
    this.metadata = const {},
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String ownerId;
  final String? guildId;
  final String bucket;
  final String path;
  final MediaType mediaType;
  final String? relatedTable;
  final String? relatedId;
  final String visibility;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
}

extension MediaTypeStorage on MediaType {
  String get storageKey {
    return switch (this) {
      MediaType.image => 'image',
      MediaType.video => 'video',
      MediaType.audio => 'audio',
      MediaType.document => 'document',
    };
  }
}

MediaType mediaTypeFromStorage(String value) {
  return MediaType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => MediaType.image,
  );
}
