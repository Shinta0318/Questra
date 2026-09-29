import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrailPaginationState {
  const TrailPaginationState({
    this.hasMore = false,
    this.isLoading = false,
    this.errorMessage,
  });

  final bool hasMore;
  final bool isLoading;
  final String? errorMessage;

  bool get canRequestMore => hasMore || errorMessage != null;
}

final trailPaginationControllerProvider =
    NotifierProvider<TrailPaginationController, TrailPaginationState>(
      TrailPaginationController.new,
    );

class TrailPaginationController extends Notifier<TrailPaginationState> {
  @override
  TrailPaginationState build() => const TrailPaginationState();

  void reset() => state = const TrailPaginationState();

  void loading() =>
      state = TrailPaginationState(hasMore: state.hasMore, isLoading: true);

  void loaded({required bool hasMore}) {
    state = TrailPaginationState(hasMore: hasMore);
  }

  void failed() {
    state = TrailPaginationState(
      hasMore: state.hasMore,
      errorMessage: '過去のTrailを読み込めませんでした。もう一度お試しください。',
    );
  }
}
