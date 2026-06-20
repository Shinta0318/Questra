import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PersistenceSyncStatus { idle, loading, saved, failed }

class PersistenceSyncState {
  const PersistenceSyncState({
    this.status = PersistenceSyncStatus.idle,
    this.message,
  });

  final PersistenceSyncStatus status;
  final String? message;

  bool get isActive => status != PersistenceSyncStatus.idle;
  bool get isFailed => status == PersistenceSyncStatus.failed;
}

class PersistenceSyncController extends Notifier<PersistenceSyncState> {
  @override
  PersistenceSyncState build() => const PersistenceSyncState();

  void loading(String message) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.loading,
      message: message,
    );
  }

  void saved(String message) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.saved,
      message: message,
    );
  }

  void failed(String scope, Object error) {
    state = PersistenceSyncState(
      status: PersistenceSyncStatus.failed,
      message: '$scope failed: $error',
    );
  }

  void clear() {
    state = const PersistenceSyncState();
  }
}
