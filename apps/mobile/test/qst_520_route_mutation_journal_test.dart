import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/route_mutation_journal.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic webOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic webOptions,
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    dynamic aOptions,
    dynamic iOptions,
    dynamic lOptions,
    dynamic mOptions,
    dynamic wOptions,
    dynamic webOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  const before = <String, Object?>{
    'snapshotVersion': 2,
    'quest': {'id': 'quest', 'targetDate': null},
    'missions': <Object?>[],
    'tasks': <Object?>[],
  };
  const after = <String, Object?>{
    'snapshotVersion': 2,
    'quest': {'id': 'quest', 'targetDate': '2028-10-01'},
    'missions': <Object?>[],
    'tasks': <Object?>[],
  };

  test(
    'owner-scoped journal survives repository recreation and never auto-applies',
    () async {
      final storage = _MemoryStorage();
      final now = DateTime.utc(2026, 9, 30);
      final first = SecureRouteMutationJournalRepository(
        storage: storage,
        clock: () => now,
      );
      await first.save(
        RouteMutationJournal(
          ownerId: 'owner-a',
          questId: 'quest',
          proposalId: 'proposal',
          stage: RouteJournalStage.applying,
          beforeSnapshot: before,
          createdAt: now,
        ),
      );
      final restarted = SecureRouteMutationJournalRepository(
        storage: storage,
        clock: () => now,
      );
      final loaded = await restarted.load('owner-a', 'quest');
      expect(loaded, isNotNull);
      expect(loaded!.disposition(before), RouteJournalDisposition.notApplied);
      expect(loaded.disposition(after), RouteJournalDisposition.unknown);
      expect(await restarted.load('owner-b', 'quest'), isNull);
      await restarted.save(
        loaded.copyWith(stage: RouteJournalStage.applied, afterSnapshot: after),
      );
      expect(
        (await restarted.load('owner-a', 'quest'))!.disposition(after),
        RouteJournalDisposition.applied,
      );
      await restarted.clear('owner-a', 'quest');
      expect(await restarted.load('owner-a', 'quest'), isNull);
    },
  );

  test('expired and corrupt journals fail closed', () async {
    final storage = _MemoryStorage();
    final now = DateTime.utc(2026, 9, 30);
    final repository = SecureRouteMutationJournalRepository(
      storage: storage,
      clock: () => now,
    );
    await repository.save(
      RouteMutationJournal(
        ownerId: 'owner-a',
        questId: 'quest',
        proposalId: 'proposal',
        stage: RouteJournalStage.recoveryNeeded,
        beforeSnapshot: before,
        createdAt: now.subtract(const Duration(days: 8)),
      ),
    );
    await expectLater(
      repository.load('owner-a', 'quest'),
      throwsA(isA<RouteJournalIntegrityException>()),
    );
    expect(storage.values, isNotEmpty);
    storage.values.updateAll((key, value) => '{broken-json');
    await expectLater(
      repository.load('owner-a', 'quest'),
      throwsA(isA<RouteJournalIntegrityException>()),
    );
    expect(storage.values, isNotEmpty);
  });
}
