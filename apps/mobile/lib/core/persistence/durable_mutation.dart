enum DurableMutationPhase {
  idle,
  saving,
  saved,
  failed,
  offlinePending,
  conflict,
}

enum DurableMutationDomain { quest, mission, task, trail, media }

enum DurableConflictResolution { keepLocal, useRemote, mergeManually, discard }

class DurableMutationIntent {
  const DurableMutationIntent({
    required this.ownerId,
    required this.domain,
    required this.entityId,
    required this.operation,
    required this.idempotencyKey,
    required this.expectedVersion,
    this.attempts = 0,
    this.queuedAt,
  });

  final String ownerId;
  final DurableMutationDomain domain;
  final String entityId;
  final String operation;
  final String idempotencyKey;
  final int expectedVersion;
  final int attempts;
  final DateTime? queuedAt;

  bool get isOwnerScoped => ownerId.isNotEmpty && ownerId.length <= 128;
  bool get isIdempotent => idempotencyKey.length >= 8;

  DurableMutationIntent nextAttempt({DateTime? queuedAt}) =>
      DurableMutationIntent(
        ownerId: ownerId,
        domain: domain,
        entityId: entityId,
        operation: operation,
        idempotencyKey: idempotencyKey,
        expectedVersion: expectedVersion,
        attempts: attempts + 1,
        queuedAt: queuedAt ?? this.queuedAt,
      );
}

class DurableMutationState {
  const DurableMutationState({
    this.phase = DurableMutationPhase.idle,
    this.message,
    this.intent,
    this.remoteVersion,
  });

  final DurableMutationPhase phase;
  final String? message;
  final DurableMutationIntent? intent;
  final int? remoteVersion;

  bool get isActive => phase != DurableMutationPhase.idle;
  bool get canRetry =>
      intent != null &&
      (phase == DurableMutationPhase.failed ||
          phase == DurableMutationPhase.offlinePending);
  bool get needsUserChoice => phase == DurableMutationPhase.conflict;
}

class DurableMutationPolicy {
  const DurableMutationPolicy({
    this.maxAttempts = 5,
    this.maxQueueAge = const Duration(days: 7),
  });

  final int maxAttempts;
  final Duration maxQueueAge;

  bool canQueue(
    DurableMutationIntent intent, {
    required String currentOwnerId,
  }) {
    return intent.isOwnerScoped &&
        intent.isIdempotent &&
        intent.ownerId == currentOwnerId &&
        intent.attempts <= maxAttempts;
  }

  bool isExpired(DurableMutationIntent intent, DateTime now) {
    final queuedAt = intent.queuedAt;
    if (queuedAt == null) return false;
    return now.toUtc().difference(queuedAt.toUtc()) > maxQueueAge;
  }

  DurableMutationState saving(DurableMutationIntent intent) =>
      DurableMutationState(
        phase: DurableMutationPhase.saving,
        message: intent.attempts == 0 ? '保存しています...' : '保存を再試行しています...',
        intent: intent,
      );

  DurableMutationState failed(DurableMutationIntent intent, Object error) {
    final offline = isOfflineFailure(error);
    return DurableMutationState(
      phase: offline
          ? DurableMutationPhase.offlinePending
          : DurableMutationPhase.failed,
      message: offline ? 'オフラインです。変更内容は保持されています。' : '保存できませんでした。変更内容は保持されています。',
      intent: intent,
    );
  }

  DurableMutationState conflict(
    DurableMutationIntent intent, {
    required int remoteVersion,
  }) => DurableMutationState(
    phase: DurableMutationPhase.conflict,
    message: '他の端末で更新されています。内容を確認してください。',
    intent: intent,
    remoteVersion: remoteVersion,
  );
}

bool isOfflineFailure(Object error) {
  final value = error.toString().toLowerCase();
  return value.contains('failed host lookup') ||
      value.contains('network is unreachable') ||
      value.contains('network request failed') ||
      value.contains('xmlhttprequest error') ||
      value.contains('socketexception') ||
      value.contains('offline');
}
