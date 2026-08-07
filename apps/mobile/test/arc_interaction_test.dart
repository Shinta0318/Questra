import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/experience/experience_settings_repository.dart';
import 'package:questra/core/experience/haptic_feedback_service.dart';
import 'package:questra/features/arc/arc_motion_controller.dart';
import 'package:questra/widgets/arc/arc_widget.dart';

void main() {
  testWidgets('tapping Arc emits a short happy reaction', (tester) async {
    final container = ProviderContainer(
      overrides: [
        experienceSettingsRepositoryProvider.overrideWithValue(
          InMemoryExperienceSettingsRepository(),
        ),
        hapticFeedbackServiceProvider.overrideWithValue(
          const NoopHapticFeedbackService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ArcWidget(key: Key('arc')))),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('arc')));
    await tester.pump();
    expect(
      container.read(arcMotionControllerProvider).state,
      ArcAnimationState.happy,
    );

    await tester.pump(const Duration(milliseconds: 1300));
    expect(
      container.read(arcMotionControllerProvider).state,
      ArcAnimationState.idle,
    );
  });
}
