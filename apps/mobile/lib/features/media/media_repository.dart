import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'media_model.dart';

const trailMediaBucket = 'trail-media';

abstract interface class MediaRepository {
  Future<List<MediaAttachment>> findTrailImages({
    required String ownerId,
    required String trailId,
    int limit = QuestraPerformanceLimits.trailImageAttachmentLimit,
  });

  Future<MediaAttachment> uploadTrailImage({
    required String ownerId,
    required String trailId,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  Future<MediaAttachment> replaceTrailImage({
    required String ownerId,
    required String trailId,
    required MediaAttachment current,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  Future<void> deleteTrailImage({
    required String ownerId,
    required MediaAttachment attachment,
  });
}

class InMemoryMediaRepository implements MediaRepository {
  final List<MediaAttachment> _attachments = [];

  @override
  Future<List<MediaAttachment>> findTrailImages({
    required String ownerId,
    required String trailId,
    int limit = QuestraPerformanceLimits.trailImageAttachmentLimit,
  }) async {
    return _attachments
        .where(
          (attachment) =>
              attachment.ownerId == ownerId &&
              attachment.relatedTable == 'trails' &&
              attachment.relatedId == trailId &&
              attachment.mediaType == MediaType.image,
        )
        .take(limit)
        .toList(growable: false);
  }

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

  @override
  Future<MediaAttachment> replaceTrailImage({
    required String ownerId,
    required String trailId,
    required MediaAttachment current,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    await deleteTrailImage(ownerId: ownerId, attachment: current);
    return uploadTrailImage(
      ownerId: ownerId,
      trailId: trailId,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  @override
  Future<void> deleteTrailImage({
    required String ownerId,
    required MediaAttachment attachment,
  }) async {
    _attachments.removeWhere(
      (current) => current.ownerId == ownerId && current.id == attachment.id,
    );
  }
}

class SupabaseMediaRepository implements MediaRepository {
  const SupabaseMediaRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<MediaAttachment>> findTrailImages({
    required String ownerId,
    required String trailId,
    int limit = QuestraPerformanceLimits.trailImageAttachmentLimit,
  }) async {
    final rows = await client
        .from('media')
        .select(
          'id,owner_id,guild_id,bucket,path,media_type,related_table,related_id,visibility,metadata,created_at',
        )
        .eq('owner_id', ownerId)
        .eq('related_table', 'trails')
        .eq('related_id', trailId)
        .eq('media_type', 'image')
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map((row) => _attachmentFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

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

    var shouldCleanUpStorage = true;
    try {
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
            'metadata': {
              'content_type': contentType,
              'size_bytes': bytes.length,
            },
          })
          .select(
            'id,owner_id,guild_id,bucket,path,media_type,related_table,related_id,visibility,metadata,created_at',
          )
          .limit(1);

      if (rows.isEmpty) {
        throw StateError('Trail media metadata was not created.');
      }
      shouldCleanUpStorage = false;
      return _attachmentFromRow(Map<String, dynamic>.from(rows.first));
    } catch (_) {
      if (shouldCleanUpStorage) {
        try {
          await client.storage.from(trailMediaBucket).remove([path]);
        } catch (_) {
          // Preserve the original metadata failure for the caller.
        }
      }
      rethrow;
    }
  }

  @override
  Future<MediaAttachment> replaceTrailImage({
    required String ownerId,
    required String trailId,
    required MediaAttachment current,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final replacement = await uploadTrailImage(
      ownerId: ownerId,
      trailId: trailId,
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
    try {
      await deleteTrailImage(ownerId: ownerId, attachment: current);
    } catch (_) {
      try {
        await deleteTrailImage(ownerId: ownerId, attachment: replacement);
      } catch (_) {
        // Preserve the original delete failure for the caller.
      }
      rethrow;
    }
    return replacement;
  }

  @override
  Future<void> deleteTrailImage({
    required String ownerId,
    required MediaAttachment attachment,
  }) async {
    await client.storage.from(attachment.bucket).remove([attachment.path]);
    await client
        .from('media')
        .delete()
        .eq('owner_id', ownerId)
        .eq('id', attachment.id);
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
