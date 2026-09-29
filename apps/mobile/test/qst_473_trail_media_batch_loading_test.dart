import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/media/media_repository.dart';

void main() {
  test('Trail images are fetched as one owner-scoped map', () async {
    final repository = InMemoryMediaRepository();
    await repository.uploadTrailImage(
      ownerId: 'owner-a',
      trailId: 'trail-a',
      fileName: 'a.png',
      bytes: Uint8List.fromList([1]),
    );
    await repository.uploadTrailImage(
      ownerId: 'owner-a',
      trailId: 'trail-b',
      fileName: 'b.png',
      bytes: Uint8List.fromList([2]),
    );
    await repository.uploadTrailImage(
      ownerId: 'owner-b',
      trailId: 'trail-a',
      fileName: 'private.png',
      bytes: Uint8List.fromList([3]),
    );

    final attachments = await repository.findTrailImageMap(
      ownerId: 'owner-a',
      trailIds: ['trail-a', 'trail-b'],
    );

    expect(attachments.keys, containsAll(['trail-a', 'trail-b']));
    expect(
      attachments.values.every((item) => item.ownerId == 'owner-a'),
      isTrue,
    );
  });

  test('batch lookup returns only the newest image for each Trail', () async {
    final repository = InMemoryMediaRepository();
    final first = await repository.uploadTrailImage(
      ownerId: 'owner-a',
      trailId: 'trail-a',
      fileName: 'first.png',
      bytes: Uint8List.fromList([1]),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final latest = await repository.uploadTrailImage(
      ownerId: 'owner-a',
      trailId: 'trail-a',
      fileName: 'latest.png',
      bytes: Uint8List.fromList([2]),
    );

    final attachments = await repository.findTrailImageMap(
      ownerId: 'owner-a',
      trailIds: ['trail-a'],
    );

    expect(attachments['trail-a']?.id, latest.id);
    expect(attachments['trail-a']?.id, isNot(first.id));
  });
}
