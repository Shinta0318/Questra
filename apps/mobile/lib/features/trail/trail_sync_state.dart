import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persistence/durable_mutation.dart';

enum TrailSyncStatus { idle, loading, saved, failed }

enum TrailSyncOperation { unknown, load, save, delete, media }

class TrailSyncState {
  const TrailSyncState({
    this.status = TrailSyncStatus.idle,
    this.message,
    this.operation = TrailSyncOperation.unknown,
    this.retryAvailable = false,
    this.inputPreserved = false,
    this.offline = false,
  });

  final TrailSyncStatus status;
  final String? message;
  final TrailSyncOperation operation;
  final bool retryAvailable;
  final bool inputPreserved;
  final bool offline;

  TrailSyncState copyWith({
    TrailSyncStatus? status,
    String? message,
    bool clearMessage = false,
    TrailSyncOperation? operation,
    bool? retryAvailable,
    bool? inputPreserved,
    bool? offline,
  }) {
    return TrailSyncState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
      operation: operation ?? this.operation,
      retryAvailable: retryAvailable ?? this.retryAvailable,
      inputPreserved: inputPreserved ?? this.inputPreserved,
      offline: offline ?? this.offline,
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
    final operation = state.operation;
    final preservesInput = operation != TrailSyncOperation.load;
    final offline = isOfflineFailure(error);
    state = TrailSyncState(
      status: TrailSyncStatus.failed,
      message: offline
          ? 'Trailを同期できませんでした。オフラインの可能性があります。'
                '${preservesInput ? '入力内容は保持されています。' : ''}'
          : 'Trailを同期できませんでした。'
                '${preservesInput ? '入力内容は保持されています。' : '通信状態を確認してください。'}',
      operation: operation,
      retryAvailable: operation == TrailSyncOperation.load,
      inputPreserved: preservesInput,
      offline: offline,
    );
  }

  void clear() {
    state = const TrailSyncState();
  }
}
