import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'durable_mutation.dart';

enum PersistenceSyncStatus { idle, loading, saved, failed }

enum PersistenceSyncOperation { unknown, load, save, delete }

class PersistenceSyncState {
  const PersistenceSyncState({
    this.status = PersistenceSyncStatus.idle,
    this.message,
    this.operation = PersistenceSyncOperation.unknown,
    this.retryAvailable = false,
    this.inputPreserved = false,
    this.offline = false,
  });

  final PersistenceSyncStatus status;
  final String? message;
  final PersistenceSyncOperation operation;
  final bool retryAvailable;
  final bool inputPreserved;
  final bool offline;

  bool get isActive => status != PersistenceSyncStatus.idle;
  bool get isFailed => status == PersistenceSyncStatus.failed;
  bool get canRetry => isFailed && retryAvailable;
}

class PersistenceSyncController extends Notifier<PersistenceSyncState> {
  @override
  PersistenceSyncState build() => const PersistenceSyncState();

  void loading(
    String message, {
    PersistenceSyncOperation operation = PersistenceSyncOperation.unknown,
  }) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.loading,
      message: message,
      operation: operation,
    );
  }

  void saved(String message) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.saved,
      message: message,
      operation: state.operation,
    );
  }

  void failed(
    String scope,
    Object error, {
    bool retryAvailable = false,
    bool? inputPreserved,
  }) {
    final offline = isOfflineFailure(error);
    final preservesInput =
        inputPreserved ?? state.operation != PersistenceSyncOperation.load;
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.failed,
      message: offline
          ? '$scopeに失敗しました。オフラインの可能性があります。'
                '${preservesInput ? '変更内容は保持されています。' : ''}'
          : '$scopeに失敗しました。'
                '${preservesInput ? '変更内容は保持されています。' : '通信状態を確認してください。'}',
      operation: state.operation,
      retryAvailable: retryAvailable,
      inputPreserved: preservesInput,
      offline: offline,
    );
  }

  void clear() {
    state = const PersistenceSyncState();
  }
}

/// Keeps the latest retryable persistence action without exposing domain data
/// through shared UI state. A newer failure cannot be cleared by an older
/// request that completes out of order.
class PersistenceRetrySlot {
  int _serial = 0;
  int? _pendingSerial;
  Future<void> Function()? _pendingAction;

  int begin() => ++_serial;

  bool get hasPending => _pendingAction != null;

  void remember(int serial, Future<void> Function() action) {
    if (serial < (_pendingSerial ?? 0)) return;
    _pendingSerial = serial;
    _pendingAction = action;
  }

  void resolve(int serial) {
    if (_pendingSerial != serial) return;
    clear();
  }

  Future<bool> retry() async {
    final action = _pendingAction;
    if (action == null) return false;
    clear();
    await action();
    return true;
  }

  void clear() {
    _pendingSerial = null;
    _pendingAction = null;
  }
}
