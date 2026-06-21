import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/media/media_model.dart';
import 'package:questra/features/trail/trail_highlight_service.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  const service = TrailHighlightService();

  test('promotes reflective Trails with Quest Mission and media context', () {
    final trail = Trail(
      questId: 'quest-1',
      missionId: 'mission-1',
      title: '深い振り返り',
      summary: '今日の発見',
      content: '学びをかなり詳しく書いたTrailです。' * 8,
      trailType: TrailType.arcReflection,
    );
    final attachment = MediaAttachment(
      id: 'media-1',
      ownerId: 'user-1',
      bucket: 'trail-media',
      path: 'trail-media/image.png',
      mediaType: MediaType.image,
      visibility: 'private',
      createdAt: DateTime(2026, 6, 21),
    );

    final highlights = service.rank(
      trails: [trail],
      attachments: {trail.id: attachment},
    );

    expect(highlights.single.score, greaterThanOrEqualTo(70));
    expect(highlights.single.isStarMemoryCandidate, isTrue);
    expect(highlights.single.reason, contains('Arc Reflection'));
  });

  test('does not over-promote low-signal manual Trails', () {
    final trail = Trail(
      title: '短いメモ',
      summary: '少しだけ',
      content: '短い',
      trailType: TrailType.manualNote,
    );

    final highlights = service.rank(trails: [trail], attachments: const {});

    expect(highlights, isEmpty);
  });
}
