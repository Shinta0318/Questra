import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/config/supabase_config.dart';
import 'package:questra/features/arc_memory/arc_memory_providers.dart';
import 'package:questra/features/arc_memory/arc_memory_repository.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/quest/quest_providers.dart';
import 'package:questra/features/quest/quest_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';
import 'package:questra/features/trail/trail_providers.dart';
import 'package:questra/features/trail/trail_repository.dart';

void main() {
  test('offline preview repositories are in memory', () {
    expect(SupabaseConfig.isConfigured, isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(questRepositoryProvider),
      isA<InMemoryQuestRepository>(),
    );
    expect(
      container.read(missionRepositoryProvider),
      isA<InMemoryMissionRepository>(),
    );
    expect(
      container.read(taskRepositoryProvider),
      isA<InMemoryTaskRepository>(),
    );
    expect(
      container.read(trailRepositoryProvider),
      isA<InMemoryTrailRepository>(),
    );
    expect(
      container.read(arcMemoryRepositoryProvider),
      isA<InMemoryArcMemoryRepository>(),
    );
  });

  test('a fresh provider scope cannot recover a preview Quest', () async {
    final first = ProviderContainer();
    final quest = Quest(
      title: 'テスト用Quest',
      description: '',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
    );
    await first
        .read(questRepositoryProvider)
        .save(ownerId: 'preview', quest: quest);
    expect(
      await first.read(questRepositoryProvider).findByUser('preview'),
      hasLength(1),
    );
    first.dispose();

    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    expect(
      await reloaded.read(questRepositoryProvider).findByUser('preview'),
      isEmpty,
    );
  });
}
