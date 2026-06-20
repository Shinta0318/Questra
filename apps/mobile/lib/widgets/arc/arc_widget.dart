import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/performance/performance_limits.dart';
import '../../core/theme/questra_colors.dart';
import '../motion/questra_motion.dart';
import 'arc_asset_paths.dart';
import 'arc_emotion.dart';
import 'arc_speech_bubble.dart';

class ArcWidget extends StatefulWidget {
  const ArcWidget({
    this.emotion = ArcEmotion.normal,
    this.message,
    this.size = QuestraPerformanceLimits.arcAssetMaxDisplaySize,
    this.showSpeechBubble = true,
    super.key,
  });

  final ArcEmotion emotion;
  final String? message;
  final double size;
  final bool showSpeechBubble;

  @override
  State<ArcWidget> createState() => _ArcWidgetState();
}

class _ArcWidgetState extends State<ArcWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _ArcVisuals.fromEmotion(widget.emotion).duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ArcWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion) {
      _controller.duration = _ArcVisuals.fromEmotion(widget.emotion).duration;
      _syncAnimation(reset: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = _ArcVisuals.fromEmotion(widget.emotion);
    final assetPath = ArcAssetPaths.fromEmotion(widget.emotion);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (disableAnimations)
          _ArcStarCharacter(
            size: widget.size,
            visuals: visuals,
            assetPath: assetPath,
          )
        else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = QuestraMotion.gentle.transform(_controller.value);
              final scale = 1 + visuals.pulseStrength * math.sin(t * math.pi);
              final tilt = visuals.tilt * math.sin(t * math.pi * 2);

              return Transform.rotate(
                angle: tilt,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: _ArcStarCharacter(
              size: widget.size,
              visuals: visuals,
              assetPath: assetPath,
            ),
          ),
        if (widget.message != null && widget.showSpeechBubble) ...[
          const SizedBox(height: 14),
          ArcSpeechBubble(message: widget.message!),
        ],
      ],
    );
  }

  void _syncAnimation({bool reset = false}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return;
    }
    if (reset) {
      _controller.reset();
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }
}

class _ArcStarCharacter extends StatelessWidget {
  const _ArcStarCharacter({
    required this.size,
    required this.visuals,
    required this.assetPath,
  });

  final double size;
  final _ArcVisuals visuals;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: visuals.glow.withValues(alpha: visuals.glowAlpha),
                  blurRadius: visuals.glowRadius,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return _GeneratedArcStar(size: size, visuals: visuals);
            },
          ),
        ],
      ),
    );
  }
}

class _GeneratedArcStar extends StatelessWidget {
  const _GeneratedArcStar({required this.size, required this.visuals});

  final double size;
  final _ArcVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipPath(
          clipper: _StarClipper(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [visuals.highlight, visuals.core, visuals.shadow],
                center: Alignment.topLeft,
                radius: 0.95,
              ),
            ),
          ),
        ),
        ClipPath(
          clipper: _StarClipper(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: QuestraColors.gold, width: 2),
            ),
          ),
        ),
        Positioned(
          top: size * 0.35,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ArcEye(size: size * 0.11, sparkle: visuals.eyeSparkle),
              SizedBox(width: size * 0.18),
              _ArcEye(size: size * 0.11, sparkle: visuals.eyeSparkle),
            ],
          ),
        ),
        Positioned(
          top: size * 0.50,
          child: CustomPaint(
            size: Size(size * 0.26, size * 0.14),
            painter: _ArcMouthPainter(visuals.expression),
          ),
        ),
        Positioned(
          top: size * 0.18,
          right: size * 0.20,
          child: Icon(
            visuals.accentIcon,
            color: QuestraColors.white.withValues(alpha: 0.88),
            size: size * 0.16,
          ),
        ),
      ],
    );
  }
}

class _ArcEye extends StatelessWidget {
  const _ArcEye({required this.size, required this.sparkle});

  final double size;
  final bool sparkle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: QuestraColors.skyBlue,
        shape: BoxShape.circle,
      ),
      child: Align(
        alignment: sparkle ? Alignment.topRight : Alignment.center,
        child: Container(
          width: size * 0.32,
          height: size * 0.32,
          decoration: const BoxDecoration(
            color: QuestraColors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _StarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.48;
    final path = Path();

    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

enum _ArcExpression { smile, openSmile, calm, serious, worried, small, cheer }

class _ArcMouthPainter extends CustomPainter {
  const _ArcMouthPainter(this.expression);

  final _ArcExpression expression;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = QuestraColors.deepNavy
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (expression) {
      case _ArcExpression.smile:
      case _ArcExpression.calm:
        path.moveTo(size.width * 0.18, size.height * 0.30);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.92,
          size.width * 0.82,
          size.height * 0.30,
        );
      case _ArcExpression.openSmile:
      case _ArcExpression.cheer:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.52),
            width: size.width * 0.48,
            height: size.height * 0.64,
          ),
          paint..style = PaintingStyle.fill,
        );
        return;
      case _ArcExpression.serious:
        path.moveTo(size.width * 0.24, size.height * 0.58);
        path.lineTo(size.width * 0.76, size.height * 0.58);
      case _ArcExpression.worried:
        path.moveTo(size.width * 0.18, size.height * 0.70);
        path.quadraticBezierTo(
          size.width * 0.50,
          size.height * 0.16,
          size.width * 0.82,
          size.height * 0.70,
        );
      case _ArcExpression.small:
        path.moveTo(size.width * 0.36, size.height * 0.58);
        path.lineTo(size.width * 0.64, size.height * 0.58);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcMouthPainter oldDelegate) {
    return oldDelegate.expression != expression;
  }
}

class _ArcVisuals {
  const _ArcVisuals({
    required this.core,
    required this.highlight,
    required this.shadow,
    required this.glow,
    required this.expression,
    required this.accentIcon,
    required this.duration,
    required this.pulseStrength,
    required this.glowAlpha,
    required this.glowRadius,
    required this.tilt,
    required this.eyeSparkle,
  });

  final Color core;
  final Color highlight;
  final Color shadow;
  final Color glow;
  final _ArcExpression expression;
  final IconData accentIcon;
  final Duration duration;
  final double pulseStrength;
  final double glowAlpha;
  final double glowRadius;
  final double tilt;
  final bool eyeSparkle;

  factory _ArcVisuals.fromEmotion(ArcEmotion emotion) {
    return switch (emotion) {
      ArcEmotion.normal => const _ArcVisuals(
        core: QuestraColors.cosmicBlue,
        highlight: QuestraColors.skyBlue,
        shadow: QuestraColors.midnightNavy,
        glow: QuestraColors.skyBlue,
        expression: _ArcExpression.smile,
        accentIcon: Icons.auto_awesome,
        duration: Duration(milliseconds: 1700),
        pulseStrength: 0.018,
        glowAlpha: 0.28,
        glowRadius: 28,
        tilt: 0.018,
        eyeSparkle: true,
      ),
      ArcEmotion.excited => const _ArcVisuals(
        core: Color(0xFF1CB5E0),
        highlight: Color(0xFFB8F7FF),
        shadow: QuestraColors.cosmicBlue,
        glow: QuestraColors.gold,
        expression: _ArcExpression.openSmile,
        accentIcon: Icons.star,
        duration: Duration(milliseconds: 900),
        pulseStrength: 0.050,
        glowAlpha: 0.42,
        glowRadius: 36,
        tilt: 0.044,
        eyeSparkle: true,
      ),
      ArcEmotion.support => const _ArcVisuals(
        core: Color(0xFF2FBF71),
        highlight: Color(0xFFB8F5D1),
        shadow: QuestraColors.cosmicBlue,
        glow: Color(0xFFB8F5D1),
        expression: _ArcExpression.calm,
        accentIcon: Icons.favorite,
        duration: Duration(milliseconds: 2100),
        pulseStrength: 0.014,
        glowAlpha: 0.34,
        glowRadius: 30,
        tilt: 0.010,
        eyeSparkle: false,
      ),
      ArcEmotion.serious => const _ArcVisuals(
        core: QuestraColors.midnightNavy,
        highlight: QuestraColors.cosmicBlue,
        shadow: QuestraColors.deepNavy,
        glow: QuestraColors.cosmicBlue,
        expression: _ArcExpression.serious,
        accentIcon: Icons.navigation,
        duration: Duration(milliseconds: 2400),
        pulseStrength: 0.006,
        glowAlpha: 0.24,
        glowRadius: 22,
        tilt: 0.004,
        eyeSparkle: false,
      ),
      ArcEmotion.worried => const _ArcVisuals(
        core: Color(0xFF7B61FF),
        highlight: Color(0xFFD7C8FF),
        shadow: QuestraColors.midnightNavy,
        glow: Color(0xFFD7C8FF),
        expression: _ArcExpression.worried,
        accentIcon: Icons.help_outline,
        duration: Duration(milliseconds: 1300),
        pulseStrength: 0.024,
        glowAlpha: 0.26,
        glowRadius: 24,
        tilt: 0.028,
        eyeSparkle: false,
      ),
      ArcEmotion.lonely => const _ArcVisuals(
        core: Color(0xFF5F6F89),
        highlight: Color(0xFFC7D0DD),
        shadow: QuestraColors.deepNavy,
        glow: Color(0xFFC7D0DD),
        expression: _ArcExpression.small,
        accentIcon: Icons.nights_stay,
        duration: Duration(milliseconds: 2600),
        pulseStrength: 0.008,
        glowAlpha: 0.20,
        glowRadius: 20,
        tilt: 0.006,
        eyeSparkle: false,
      ),
      ArcEmotion.celebrate => const _ArcVisuals(
        core: QuestraColors.gold,
        highlight: Color(0xFFFFF1B8),
        shadow: QuestraColors.cosmicBlue,
        glow: QuestraColors.gold,
        expression: _ArcExpression.cheer,
        accentIcon: Icons.celebration,
        duration: Duration(milliseconds: 760),
        pulseStrength: 0.060,
        glowAlpha: 0.50,
        glowRadius: 40,
        tilt: 0.055,
        eyeSparkle: true,
      ),
    };
  }
}
