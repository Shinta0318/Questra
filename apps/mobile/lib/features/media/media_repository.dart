import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, SupabaseClient;

import 'media_model.dart';

const trailMediaBucket = 'trail-media';

abstract interface class MediaRepository {
  Future<MediaAttachment> uploadTrailImage({
    required String ownerId,
    required String trailId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });
}

class InMemoryMediaRepository implements MediaRepository {
  final List<MediaAttachment> _attachments = [];

  @override
  Future<MediaAttachment> uploadTrailImage({
    required String ownerId,
    required String trailId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final attachment = MediaAttachment(
      ownerId: ownerId,
      bucket: trailMediaBucket,
      path: _trailMediaPath(ownerId, trailId, fileName),
      mediaType: MediaType.image,
      relatedTable: 'trails',
      relatedId: trailId,
      metadata: {'content_type': contentType, 'size_bytes': bytes.length},
    );
    _attachments.insert(0, attachment);
    return attachment;
  }
}

class SupabaseMediaRepository implements MediaRepository {
  const SupabaseMediaRepository(this.client);

  final SupabaseClient client;

  @override
  Future<MediaAttachment> uploadTrailImage({
    required String ownerId,
    required String trailId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final path = _trailMediaPath(ownerId, trailId, fileName);
    await client.storage
        .from(trailMediaBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    final rows = await client
        .from('media')
        .insert({
          'owner_id': ownerId,
          'bucket': trailMediaBucket,
          'path': path,
          'media_type': 'image',
          'related_table': 'trails',
          'related_id': trailId,
          'visibility': 'private',
          'metadata': {'content_type': contentType, 'size_bytes': bytes.length},
        })
        .select()
        .limit(1);

    if (rows.isEmpty) {
      return MediaAttachment(
        ownerId: ownerId,
        bucket: trailMediaBucket,
        path: path,
        mediaType: MediaType.image,
        relatedTable: 'trails',
        relatedId: trailId,
      );
    }
    return _attachmentFromRow(Map<String, dynamic>.from(rows.first));
  }

  MediaAttachment _attachmentFromRow(Map<String, dynamic> row) {
    return MediaAttachment(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      guildId: row['guild_id'] as String?,
      bucket: row['bucket'] as String,
      path: row['path'] as String,
      mediaType: mediaTypeFromStorage(row['media_type'] as String),
      relatedTable: row['related_table'] as String?,
      relatedId: row['related_id'] as String?,
      visibility: row['visibility'] as String? ?? 'private',
      metadata: Map<String, Object?>.from(row['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

String _trailMediaPath(String ownerId, String trailId, String fileName) {
  final safeName = fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$ownerId/$trailId/${timestamp}_$safeName';
}
