import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/planning_attempt_repository.dart';

void main() {
  const ownerA = '00000000-0000-4000-8000-000000000001';
  const ownerB = '00000000-0000-4000-8000-000000000002';
  const questA = '00000000-0000-4000-8000-000000000003';
  const questB = '00000000-0000-4000-8000-000000000004';
  final fingerprintA = List.filled(64, 'a').join();
  final fingerprintB = List.filled(64, 'b').join();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('restart reuses only the same owner and Quest attempt', () async {
    final first = SecurePlanningAttemptRepository(
      newId: () => '00000000-0000-4000-8000-000000000010',
    );
    final attempt = await first.loadOrCreate(ownerA, questA, fingerprintA);
    final restarted = SecurePlanningAttemptRepository(
      newId: () => '00000000-0000-4000-8000-000000000011',
    );
    expect(await restarted.loadOrCreate(ownerA, questA, fingerprintA), attempt);
    expect(
      await restarted.loadOrCreate(ownerB, questA, fingerprintA),
      isNot(attempt),
    );
    expect(
      await restarted.loadOrCreate(ownerA, questB, fingerprintA),
      isNot(attempt),
    );
    expect(
      await restarted.loadOrCreate(null, questA, fingerprintA),
      isNot(attempt),
    );
    expect(
      await restarted.loadOrCreate(ownerA, questA, fingerprintB),
      isNot(attempt),
    );
  });

  test('only the matching completed attempt is cleared', () async {
    var next = 10;
    final repository = SecurePlanningAttemptRepository(
      newId: () =>
          '00000000-0000-4000-8000-${(next++).toString().padLeft(12, '0')}',
    );
    final attempt = await repository.loadOrCreate(ownerA, questA, fingerprintA);
    await repository.clear(ownerA, questA, fingerprintA, 'flutter-other');
    expect(
      await repository.loadOrCreate(ownerA, questA, fingerprintA),
      attempt,
    );
    await repository.clear(ownerA, questA, fingerprintB, attempt);
    expect(
      await repository.loadOrCreate(ownerA, questA, fingerprintA),
      attempt,
    );
    await repository.clear(ownerA, questA, fingerprintA, attempt);
    expect(
      await repository.loadOrCreate(ownerA, questA, fingerprintA),
      isNot(attempt),
    );
  });

  test('expired attempt gets a fresh ID without retaining wish text', () async {
    var now = DateTime.utc(2026, 10, 28);
    var next = 10;
    final repository = SecurePlanningAttemptRepository(
      clock: () => now,
      newId: () =>
          '00000000-0000-4000-8000-${(next++).toString().padLeft(12, '0')}',
    );
    final first = await repository.loadOrCreate(ownerA, questA, fingerprintA);
    now = now.add(const Duration(hours: 25));
    final second = await repository.loadOrCreate(ownerA, questA, fingerprintA);
    expect(second, isNot(first));
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.values.join(), isNot(contains('シンガポール')));
    expect(stored.values.join(), isNot(contains('wish')));
  });
}
