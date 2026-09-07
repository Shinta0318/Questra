import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrailSyncStatus { idle, loading, saved, failed }

enum TrailSyncOperation { unknown, load, save, delete, media }

class TrailSyncState {
  const TrailSyncState({
    this.status = TrailSyncStatus.idle,
    this.message,
    this.operation = TrailSyncOperation.unknown,
  });

  final TrailSyncStatus status;
  final String? message;
  final TrailSyncOperation operation;

  TrailSyncState copyWith({
    TrailSyncStatus? status,
    String? message,
    bool clearMessage = false,
    TrailSyncOperation? operation,
  }) {
    return TrailSyncState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      operation: operation ?? this.operation,
    );
  }
}

final trailSyncControllerProvider =
    NotifierProvider<TrailSyncController, TrailSyncState>(
      TrailSyncController.new,
    );

class TrailSyncController extends Notifier<TrailSyncState> {
  @override
  TrailSyncState build() => const TrailSyncState();

  void loading([
    String message = 'Trailを同期しています...',
    TrailSyncOperation operation = TrailSyncOperation.unknown,
  ]) {
    state = TrailSyncState(
      status: TrailSyncStatus.loading,
      message: message,
      operation: operation,
    );
  }

  void saved([String message = 'Trailを保存しました。']) {
    state = TrailSyncState(
      status: TrailSyncStatus.saved,
      message: message,
      operation: state.operation,
    );
  }

  void failed(Object error) {
    state = TrailSyncState(
      status: TrailSyncStatus.failed,
      message: 'Trailを同期できませんでした。通信状態を確認して、もう一度お試しください。',
      operation: state.operation,
    );
  }

  void clear() {
    state = const TrailSyncState();
  }
}
