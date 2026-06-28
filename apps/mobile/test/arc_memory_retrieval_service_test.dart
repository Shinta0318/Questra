import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/arc_memory/arc_memory_retrieval_service.dart';

void main() {
  const service = ArcMemoryRetrievalService();
  final now = DateTime.utc(2026, 6, 28);

  ArcMemory memory({
    required String id,
    required String content,
    double importance = 0.5,
    String? questId,
    SensitivityLevel sensitivity = SensitivityLevel.standard,
    int ageInDays = 0,
  }) {
    final timestamp = now.subtract(Duration(days: ageInDays));
    return ArcMemory(
      id: id,
      userId: 'user-1',
      questId: questId,
      memoryType: ArcMemoryType.questMemory,
      title: id,
      content: content,
      importanceScore: importance,
      emotionalTone: EmotionalTone.neutral,
      sourceType: ArcMemorySourceType.arcChat,
      sensitivityLevel: sensitivity,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  test('ranks matching and Quest-related memories ahead of generic ones', () {
    final result = service.retrieve(
      memories: [
        memory(
          id: 'generic',
          content: 'A generally important memory',
          importance: 0.9,
        ),
        memory(
          id: 'matched',
          content: 'The user prefers quiet writing in the morning',
          importance: 0.5,
        ),
        memory(
          id: 'quest',
          content: 'A step connected to the active Quest',
          importance: 0.4,
          questId: 'quest-1',
        ),
      ],
      query: 'quiet writing',
      questIds: {'quest-1'},
      now: now,
    );

    expect(result.map((item) => item.id), ['matched', 'quest', 'generic']);
  });

  test('excludes sensitive memories by default and honors the limit', () {
    final result = service.retrieve(
      memories: [
        memory(
          id: 'sensitive',
          content: 'Private context',
          importance: 1,
          sensitivity: SensitivityLevel.sensitive,
        ),
        memory(id: 'recent', content: 'Recent context', importance: 0.6),
        memory(
          id: 'older',
          content: 'Older context',
          importance: 0.6,
          ageInDays: 90,
        ),
      ],
      query: '',
      limit: 1,
      now: now,
    );

    expect(result.single.id, 'recent');
  });
}
