import 'arc_emotion.dart';

enum ArcAnimationEventType {
  idle,
  blink,
  celebrate,
  concern,
  thinking,
  transition,
}

enum ArcAnimationIntensity { subtle, standard, strong }

class ArcAnimationEvent {
  const ArcAnimationEvent({
    required this.type,
    required this.duration,
    required this.pulseStrength,
    required this.tilt,
    required this.loop,
    required this.intensity,
    required this.rendererHint,
  });

  final ArcAnimationEventType type;
  final Duration duration;
  final double pulseStrength;
  final double tilt;
  final bool loop;
  final ArcAnimationIntensity intensity;
  final String rendererHint;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ArcAnimationEvent &&
            type == other.type &&
            duration == other.duration &&
            pulseStrength == other.pulseStrength &&
            tilt == other.tilt &&
            loop == other.loop &&
            intensity == other.intensity &&
            rendererHint == other.rendererHint;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      duration,
      pulseStrength,
      tilt,
      loop,
      intensity,
      rendererHint,
    );
  }
}

class ArcAnimationEvents {
  const ArcAnimationEvents._();

  static const idle = ArcAnimationEvent(
    type: ArcAnimationEventType.idle,
    duration: Duration(milliseconds: 1700),
    pulseStrength: 0.018,
    tilt: 0.018,
    loop: true,
    intensity: ArcAnimationIntensity.standard,
    rendererHint: 'gentle PNG pulse; future renderers may map to idle loop',
  );

  static const blink = ArcAnimationEvent(
    type: ArcAnimationEventType.blink,
    duration: Duration(milliseconds: 2100),
    pulseStrength: 0.014,
    tilt: 0.010,
    loop: true,
    intensity: ArcAnimationIntensity.subtle,
    rendererHint: 'soft supportive loop with occasional blink',
  );

  static const celebrate = ArcAnimationEvent(
    type: ArcAnimationEventType.celebrate,
    duration: Duration(milliseconds: 760),
    pulseStrength: 0.060,
    tilt: 0.055,
    loop: true,
    intensity: ArcAnimationIntensity.strong,
    rendererHint: 'bright celebration bounce',
  );

  static const concern = ArcAnimationEvent(
    type: ArcAnimationEventType.concern,
    duration: Duration(milliseconds: 1300),
    pulseStrength: 0.024,
    tilt: 0.028,
    loop: true,
    intensity: ArcAnimationIntensity.standard,
    rendererHint: 'small worried sway',
  );

  static const thinking = ArcAnimationEvent(
    type: ArcAnimationEventType.thinking,
    duration: Duration(milliseconds: 2400),
    pulseStrength: 0.006,
    tilt: 0.004,
    loop: true,
    intensity: ArcAnimationIntensity.subtle,
    rendererHint: 'slow focused shimmer; future renderers may map to thinking',
  );

  static const transition = ArcAnimationEvent(
    type: ArcAnimationEventType.transition,
    duration: Duration(milliseconds: 900),
    pulseStrength: 0.050,
    tilt: 0.044,
    loop: true,
    intensity: ArcAnimationIntensity.strong,
    rendererHint: 'quick delighted transition',
  );
}

class ArcAnimationEventResolver {
  const ArcAnimationEventResolver._();

  static ArcAnimationEvent forEmotion(ArcEmotion emotion) {
    return switch (emotion) {
      ArcEmotion.normal => ArcAnimationEvents.idle,
      ArcEmotion.excited => ArcAnimationEvents.transition,
      ArcEmotion.support => ArcAnimationEvents.blink,
      ArcEmotion.serious => ArcAnimationEvents.thinking,
      ArcEmotion.worried => ArcAnimationEvents.concern,
      ArcEmotion.lonely => ArcAnimationEvents.thinking,
      ArcEmotion.celebrate => ArcAnimationEvents.celebrate,
    };
  }
}
