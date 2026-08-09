import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TrailSyncStatus { idle, loading, saved, failed }

class TrailSyncState {
  const TrailSyncState({this.status = TrailSyncStatus.idle, this.message});

  final TrailSyncStatus status;
  final String? message;

  TrailSyncState copyWith({
    TrailSyncStatus? status,
    String? message,
    bool clearMessage = false,
  }) {
    return TrailSyncState(
      status: status ?? this.status,
      message: clearMessage ? null : message ?? this.message,
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

  void loading([String message = 'Trailを同期しています...']) {
    state = TrailSyncState(status: TrailSyncStatus.loading, message: message);
  }

  void saved([String message = 'Trailを保存しました。']) {
    state = TrailSyncState(status: TrailSyncStatus.saved, message: message);
  }

  void failed(Object error) {
    state = TrailSyncState(
      status: TrailSyncStatus.failed,
      message: 'Trailを同期できませんでした: $error',
    );
  }

  void clear() {
    state = const TrailSyncState();
  }
}
