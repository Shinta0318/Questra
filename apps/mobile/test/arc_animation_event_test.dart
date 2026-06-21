import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_expression_engine.dart';
import 'package:questra/widgets/arc/arc_animation_event.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';
import 'package:questra/widgets/arc/arc_widget.dart';

void main() {
  test('maps Arc emotions to renderer-neutral animation events', () {
    expect(
      ArcAnimationEventResolver.forEmotion(ArcEmotion.normal).type,
      ArcAnimationEventType.idle,
    );
    expect(
      ArcAnimationEventResolver.forEmotion(ArcEmotion.support).type,
      ArcAnimationEventType.blink,
    );
    expect(
      ArcAnimationEventResolver.forEmotion(ArcEmotion.celebrate).type,
      ArcAnimationEventType.celebrate,
    );
    expect(
      ArcAnimationEventResolver.forEmotion(ArcEmotion.worried).type,
      ArcAnimationEventType.concern,
    );
  });

  test('animation event metadata is future renderer friendly', () {
    const event = ArcAnimationEvents.thinking;

    expect(event.duration.inMilliseconds, greaterThan(0));
    expect(event.pulseStrength, greaterThanOrEqualTo(0));
    expect(event.tilt, greaterThanOrEqualTo(0));
    expect(event.rendererHint, contains('future'));
    expect(event.loop, isTrue);
  });

  test('Arc expression decisions include animation events', () {
    const engine = ArcExpressionEngine();

    final decision = engine.resolve(
      const ArcExpressionContext(moment: ArcExpressionMoment.celebration),
    );

    expect(decision.animationEvent.type, ArcAnimationEventType.celebrate);
    expect(decision.animationEvent.intensity, ArcAnimationIntensity.strong);
  });

  testWidgets('ArcWidget accepts an explicit animation event', (tester) async {
    const customEvent = ArcAnimationEvent(
      type: ArcAnimationEventType.thinking,
      duration: Duration(milliseconds: 1200),
      pulseStrength: 0.01,
      tilt: 0.01,
      loop: true,
      intensity: ArcAnimationIntensity.subtle,
      rendererHint: 'test event',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ArcWidget(
            emotion: ArcEmotion.serious,
            animationEvent: customEvent,
            showSpeechBubble: false,
          ),
        ),
      ),
    );

    final widget = tester.widget<ArcWidget>(find.byType(ArcWidget));

    expect(widget.animationEvent, customEvent);
  });
}
