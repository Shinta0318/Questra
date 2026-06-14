import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/arc_memory/arc_memory_repository.dart';
import 'package:questra/features/arc_memory/memory_extraction_service.dart';

void main() {
  test('extracts and saves Quest memory from Quest creation', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(repository: repository);

    final memories = await service.extractAndSave(
      const MemoryExtractionEvent(
        userId: 'user-1',
        questId: 'quest-1',
        sourceId: 'quest-1',
        sourceType: ArcMemorySourceType.questCreated,
        text: 'Build a calm morning Quest that supports long-term writing.',
      ),
    );

    expect(memories, hasLength(1));
    expect(memories.first.memoryType, ArcMemoryType.questMemory);
    expect(memories.first.questId, 'quest-1');
    expect(memories.first.importanceScore, greaterThan(0.5));
  });

  test('classifies preference memory from Arc chat', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(repository: repository);

    final memories = await service.extractAndSave(
      const MemoryExtractionEvent(
        userId: 'user-1',
        sourceType: ArcMemorySourceType.arcChat,
        text: 'I prefer quiet guidance and value small Mission steps.',
      ),
    );

    expect(memories, hasLength(1));
    expect(memories.first.memoryType, ArcMemoryType.preferenceMemory);
    expect(memories.first.sourceType, ArcMemorySourceType.arcChat);
  });

  test('does not save low-signal short messages', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(repository: repository);

    final memories = await service.extractAndSave(
      const MemoryExtractionEvent(
        userId: 'user-1',
        sourceType: ArcMemorySourceType.arcChat,
        text: 'ok',
      ),
    );

    expect(memories, isEmpty);
    expect(await repository.findByUser('user-1'), isEmpty);
  });

  test('deduplicates repeated memory candidates', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(repository: repository);
    const event = MemoryExtractionEvent(
      userId: 'user-1',
      questId: 'quest-1',
      sourceId: 'quest-1',
      sourceType: ArcMemorySourceType.questUpdated,
      text: 'This Quest matters because it helps me build confidence.',
    );

    final first = await service.extractAndSave(event);
    final second = await service.extractAndSave(event);

    expect(first, hasLength(1));
    expect(second, isEmpty);
    expect(await repository.findByUser('user-1'), hasLength(1));
  });

  test('redacts personal contact details before saving', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(repository: repository);

    final memories = await service.extractAndSave(
      const MemoryExtractionEvent(
        userId: 'user-1',
        sourceType: ArcMemorySourceType.arcChat,
        text: 'My family update is important; email me at arc@example.com.',
      ),
    );

    expect(memories, hasLength(1));
    expect(memories.first.content, contains('[redacted-email]'));
    expect(memories.first.content, isNot(contains('arc@example.com')));
    expect(memories.first.sensitivityLevel, SensitivityLevel.personal);
  });
}
