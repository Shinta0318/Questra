import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/onboarding/onboarding_tour_controller.dart';

void main() {
  test('tour appears only when profile has not seen it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(
      onboardingTourControllerProvider.notifier,
    );

    controller.showIfNeeded(profileHasSeenTour: true);
    expect(container.read(onboardingTourControllerProvider).isVisible, isFalse);

    controller.showIfNeeded(profileHasSeenTour: false);
    expect(container.read(onboardingTourControllerProvider).isVisible, isTrue);
  });

  test('dismiss keeps the tour quiet for the current session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(
      onboardingTourControllerProvider.notifier,
    );

    controller.showIfNeeded(profileHasSeenTour: false);
    controller.dismiss();

    final dismissed = container.read(onboardingTourControllerProvider);
    expect(dismissed.isVisible, isFalse);
    expect(dismissed.hasSeenLocalTour, isTrue);

    controller.showIfNeeded(profileHasSeenTour: false);
    expect(container.read(onboardingTourControllerProvider).isVisible, isFalse);
  });

  test('replay can show the tour after dismissal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(
      onboardingTourControllerProvider.notifier,
    );

    controller.showIfNeeded(profileHasSeenTour: false);
    controller.dismiss();
    controller.replay();

    expect(container.read(onboardingTourControllerProvider).isVisible, isTrue);
  });
}
