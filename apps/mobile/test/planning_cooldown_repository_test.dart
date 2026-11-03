import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/quest/planning_cooldown_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cooldown survives repository recreation without crossing accounts',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      var now = DateTime.utc(2026, 10, 26, 12);
      final first = SecurePlanningCooldownRepository(clock: () => now);
      final retryAt = now.add(const Duration(minutes: 2));
      await first.save('owner-a', 'quest-1', retryAt);

      final restarted = SecurePlanningCooldownRepository(clock: () => now);
      expect(await restarted.load('owner-a', 'quest-1'), retryAt);
      expect(await restarted.load('owner-b', 'quest-1'), isNull);
      expect(await restarted.load('owner-a', 'quest-2'), isNull);

      now = now.add(const Duration(minutes: 3));
      expect(await restarted.load('owner-a', 'quest-1'), isNull);
    },
  );

  test('invalid or distant timestamps do not keep planning blocked', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final now = DateTime.utc(2026, 10, 26, 12);
    final repository = SecurePlanningCooldownRepository(clock: () => now);
    await repository.save(
      'owner-a',
      'quest-1',
      now.add(const Duration(days: 1)),
    );
    expect(await repository.load('owner-a', 'quest-1'), isNull);
    expect(await repository.load('', 'quest-1'), isNull);
  });
}
