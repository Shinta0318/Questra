import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_motion_controller.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  test('Arc motion controller emits and clears a cheering reaction', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(arcMotionControllerProvider.notifier);

    final pending = controller.react(
      ArcAnimationState.cheering,
      duration: const Duration(milliseconds: 1),
    );
    expect(container.read(arcMotionControllerProvider).state,
        ArcAnimationState.cheering);
    expect(container.read(arcMotionControllerProvider).emotionOverride,
        ArcEmotion.celebrate);

    await pending;
    expect(container.read(arcMotionControllerProvider).state,
        ArcAnimationState.idle);
    expect(container.read(arcMotionControllerProvider).emotionOverride, isNull);
  });

  test('long press reactions do not repeat consecutively', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(arcMotionControllerProvider.notifier);

    final first = controller.reactToLongPress();
    final firstState = container.read(arcMotionControllerProvider).state;
    final second = controller.reactToLongPress();
    final secondState = container.read(arcMotionControllerProvider).state;

    expect(firstState, isNot(secondState));
    await Future.wait([first, second]);
  });
}
