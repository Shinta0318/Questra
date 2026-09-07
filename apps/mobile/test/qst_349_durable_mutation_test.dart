import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/persistence/durable_mutation.dart';

void main() {
  const policy = DurableMutationPolicy();

  test('accepts only owner-scoped idempotent mutation intents', () {
    final intent = _intent(ownerId: 'user-1');

    expect(policy.canQueue(intent, currentOwnerId: 'user-1'), isTrue);
    expect(policy.canQueue(intent, currentOwnerId: 'user-2'), isFalse);
    expect(
      policy.canQueue(
        _intent(ownerId: 'user-1', idempotencyKey: 'short'),
        currentOwnerId: 'user-1',
      ),
      isFalse,
    );
  });

  test('marks old queued mutations as expired', () {
    final intent = _intent(
      ownerId: 'user-1',
      queuedAt: DateTime.utc(2026, 8, 1),
    );

    expect(policy.isExpired(intent, DateTime.utc(2026, 8, 5)), isFalse);
    expect(policy.isExpired(intent, DateTime.utc(2026, 8, 12)), isTrue);
  });

  test('distinguishes offline pending from regular failures', () {
    final intent = _intent(ownerId: 'user-1');

    final offline = policy.failed(intent, StateError('SocketException'));
    final failed = policy.failed(intent, StateError('permission denied'));

    expect(offline.phase, DurableMutationPhase.offlinePending);
    expect(offline.canRetry, isTrue);
    expect(failed.phase, DurableMutationPhase.failed);
    expect(failed.canRetry, isTrue);
  });

  test('conflict state requires user choice and keeps remote version', () {
    final state = policy.conflict(_intent(ownerId: 'user-1'), remoteVersion: 7);

    expect(state.phase, DurableMutationPhase.conflict);
    expect(state.needsUserChoice, isTrue);
    expect(state.remoteVersion, 7);
  });
}

DurableMutationIntent _intent({
  required String ownerId,
  String idempotencyKey = 'mutation-key-1',
  DateTime? queuedAt,
}) => DurableMutationIntent(
  ownerId: ownerId,
  domain: DurableMutationDomain.quest,
  entityId: 'quest-1',
  operation: 'update',
  idempotencyKey: idempotencyKey,
  expectedVersion: 3,
  queuedAt: queuedAt,
);
