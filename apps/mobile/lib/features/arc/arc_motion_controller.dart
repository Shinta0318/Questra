import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/arc/arc_animation_event.dart';
import '../../widgets/arc/arc_emotion.dart';

enum ArcAnimationState {
  idle,
  listening,
  thinking,
  speaking,
  happy,
  cheering,
  celebration,
  serious,
  worried,
  sad,
  sleep,
}

class ArcMotionReaction {
  const ArcMotionReaction({
    this.state = ArcAnimationState.idle,
    this.emotionOverride,
    this.event,
    this.revision = 0,
  });

  final ArcAnimationState state;
  final ArcEmotion? emotionOverride;
  final ArcAnimationEvent? event;
  final int revision;
}

final arcMotionControllerProvider =
    NotifierProvider<ArcMotionController, ArcMotionReaction>(
  ArcMotionController.new,
);

class ArcMotionController extends Notifier<ArcMotionReaction> {
  var _longPressIndex = 0;

  @override
  ArcMotionReaction build() => const ArcMotionReaction();

  Future<void> react(
    ArcAnimationState animationState, {
    Duration duration = const Duration(milliseconds: 1200),
  }) async {
    final revision = state.revision + 1;
    state = _reactionFor(animationState, revision);
    await Future<void>.delayed(duration);
    if (state.revision != revision) return;
    state = ArcMotionReaction(revision: revision + 1);
  }

  Future<void> reactToLongPress() {
    const reactions = [
      ArcAnimationState.happy,
      ArcAnimationState.listening,
      ArcAnimationState.worried,
    ];
    final reaction = reactions[_longPressIndex % reactions.length];
    _longPressIndex++;
    return react(reaction);
  }

  ArcMotionReaction _reactionFor(
    ArcAnimationState animationState,
    int revision,
  ) {
    final (emotion, event) = switch (animationState) {
      ArcAnimationState.idle => (null, ArcAnimationEvents.idle),
      ArcAnimationState.listening => (
          ArcEmotion.normal,
          ArcAnimationEvents.transition
        ),
      ArcAnimationState.thinking => (
          ArcEmotion.serious,
          ArcAnimationEvents.thinking
        ),
      ArcAnimationState.speaking => (
          ArcEmotion.support,
          ArcAnimationEvents.blink
        ),
      ArcAnimationState.happy => (
          ArcEmotion.excited,
          ArcAnimationEvents.transition
        ),
      ArcAnimationState.cheering => (
          ArcEmotion.celebrate,
          ArcAnimationEvents.celebrate
        ),
      ArcAnimationState.celebration => (
          ArcEmotion.celebrate,
          ArcAnimationEvents.celebrate
        ),
      ArcAnimationState.serious => (
          ArcEmotion.serious,
          ArcAnimationEvents.thinking
        ),
      ArcAnimationState.worried => (
          ArcEmotion.worried,
          ArcAnimationEvents.concern
        ),
      ArcAnimationState.sad => (ArcEmotion.lonely, ArcAnimationEvents.thinking),
      ArcAnimationState.sleep => (
          ArcEmotion.lonely,
          ArcAnimationEvents.thinking
        ),
    };
    return ArcMotionReaction(
      state: animationState,
      emotionOverride: emotion,
      event: event,
      revision: revision,
    );
  }
}
