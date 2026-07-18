import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';

class QuestraScreenSurface extends StatelessWidget {
  const QuestraScreenSurface({
    required this.child,
    this.useSafeArea = true,
    super.key,
  });

  final Widget child;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final content = useSafeArea ? SafeArea(child: child) : child;

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.adventure),
      child: content,
    );
  }
}
