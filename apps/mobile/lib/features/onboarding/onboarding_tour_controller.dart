import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingTourControllerProvider =
    NotifierProvider<OnboardingTourController, OnboardingTourState>(
      OnboardingTourController.new,
    );

class OnboardingTourState {
  const OnboardingTourState({
    this.isVisible = false,
    this.hasSeenLocalTour = false,
  });

  final bool isVisible;
  final bool hasSeenLocalTour;

  OnboardingTourState copyWith({bool? isVisible, bool? hasSeenLocalTour}) {
    return OnboardingTourState(
      isVisible: isVisible ?? this.isVisible,
      hasSeenLocalTour: hasSeenLocalTour ?? this.hasSeenLocalTour,
    );
  }
}

class OnboardingTourController extends Notifier<OnboardingTourState> {
  @override
  OnboardingTourState build() => const OnboardingTourState();

  void showIfNeeded({required bool profileHasSeenTour}) {
    if (profileHasSeenTour || state.hasSeenLocalTour || state.isVisible) {
      return;
    }
    state = state.copyWith(isVisible: true);
  }

  void replay() {
    state = state.copyWith(isVisible: true);
  }

  void dismiss() {
    state = state.copyWith(isVisible: false, hasSeenLocalTour: true);
  }
}
