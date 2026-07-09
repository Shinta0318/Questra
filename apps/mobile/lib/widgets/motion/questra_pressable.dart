import 'package:flutter/material.dart';

import 'questra_motion.dart';

class QuestraPressable extends StatefulWidget {
  const QuestraPressable({
    required this.child,
    this.pressedScale = QuestraMotion.pressedScale,
    super.key,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<QuestraPressable> createState() => _QuestraPressableState();
}

class _QuestraPressableState extends State<QuestraPressable> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: disableAnimations || !_pressed ? 1 : widget.pressedScale,
        duration: disableAnimations ? Duration.zero : QuestraMotion.fast,
        curve: QuestraMotion.standard,
        child: widget.child,
      ),
    );
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed || !mounted) {
      return;
    }
    setState(() => _pressed = pressed);
  }
}
