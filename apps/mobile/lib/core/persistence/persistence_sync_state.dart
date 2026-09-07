import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PersistenceSyncStatus { idle, loading, saved, failed }

enum PersistenceSyncOperation { unknown, load, save, delete }

class PersistenceSyncState {
  const PersistenceSyncState({
    this.status = PersistenceSyncStatus.idle,
    this.message,
    this.operation = PersistenceSyncOperation.unknown,
  });

  final PersistenceSyncStatus status;
  final String? message;
  final PersistenceSyncOperation operation;

  bool get isActive => status != PersistenceSyncStatus.idle;
  bool get isFailed => status == PersistenceSyncStatus.failed;
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

  void failed(String scope, Object error) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.failed,
      message: '$scopeに失敗しました。通信状態を確認して、もう一度お試しください。',
      operation: state.operation,
    );
  }

  void clear() {
    state = const PersistenceSyncState();
  }
}
