import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingTourControllerProvider =
    NotifierProvider<OnboardingTourController, OnboardingTourState>(
      OnboardingTourController.new,
    );

class OnboardingTourState {
  const OnboardingTourState({
    this.isVisible = false,
    this.hasSeenLocalTour = false,
    this.entryPoint = OnboardingTourEntryPoint.automatic,
    this.presentationId = 0,
  });

  final bool isVisible;
  final bool hasSeenLocalTour;
  final OnboardingTourEntryPoint entryPoint;
  final int presentationId;

  bool get isReplay => entryPoint == OnboardingTourEntryPoint.replay;

  OnboardingTourState copyWith({
    bool? isVisible,
    bool? hasSeenLocalTour,
    OnboardingTourEntryPoint? entryPoint,
    int? presentationId,
  }) {
    return OnboardingTourState(
      isVisible: isVisible ?? this.isVisible,
      hasSeenLocalTour: hasSeenLocalTour ?? this.hasSeenLocalTour,
      entryPoint: entryPoint ?? this.entryPoint,
      presentationId: presentationId ?? this.presentationId,
    );
  }
}

enum OnboardingTourEntryPoint { automatic, replay }

class OnboardingTourController extends Notifier<OnboardingTourState> {
  @override
  OnboardingTourState build() => const OnboardingTourState();

  void showIfNeeded({required bool profileHasSeenTour}) {
    if (profileHasSeenTour || state.hasSeenLocalTour || state.isVisible) {
      return;
    }
    state = state.copyWith(
      isVisible: true,
      entryPoint: OnboardingTourEntryPoint.automatic,
      presentationId: state.presentationId + 1,
    );
  }

  void replay({bool enabled = true}) {
    if (!enabled) {
      return;
    }
    state = state.copyWith(
      isVisible: true,
      entryPoint: OnboardingTourEntryPoint.replay,
      presentationId: state.presentationId + 1,
    );
  }

  void dismiss() {
    state = state.copyWith(isVisible: false, hasSeenLocalTour: true);
  }
}
