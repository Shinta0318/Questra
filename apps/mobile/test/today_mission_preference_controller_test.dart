import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/today_mission_preference_controller.dart';

void main() {
  test(
    'today preference supports alternate, five minutes, rest, and resume',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        todayMissionPreferenceControllerProvider.notifier,
      );
      final today = DateTime(2026, 8, 1);

      notifier.chooseAnother('mission-1', now: today);
      expect(
        container
            .read(todayMissionPreferenceControllerProvider)
            .excludedMissionIds,
        contains('mission-1'),
      );

      notifier.useFiveMinutes('mission-2', now: today);
      expect(
        container
            .read(todayMissionPreferenceControllerProvider)
            .fiveMinuteMissionId,
        'mission-2',
      );

      notifier.restToday(now: today);
      expect(
        container.read(todayMissionPreferenceControllerProvider).isResting,
        isTrue,
      );

      notifier.resumeToday();
      expect(
        container.read(todayMissionPreferenceControllerProvider).isResting,
        isFalse,
      );
    },
  );

  test('preferences do not carry over to another day', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      todayMissionPreferenceControllerProvider.notifier,
    );

    notifier.restToday(now: DateTime(2026, 8, 1));

    expect(
      container
          .read(todayMissionPreferenceControllerProvider)
          .isFor(DateTime(2026, 8, 2)),
      isFalse,
    );
  });
}
