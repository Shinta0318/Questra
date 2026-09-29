import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Returns through the active stack, or to a safe parent for direct links.
class QuestraRouteBackButton extends StatelessWidget {
  const QuestraRouteBackButton({
    required this.fallbackRoute,
    required this.fallbackTooltip,
    super.key,
  });

  final String fallbackRoute;
  final String fallbackTooltip;

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();
    return IconButton(
      tooltip: canPop ? '戻る' : fallbackTooltip,
      onPressed: () => canPop ? context.pop() : context.go(fallbackRoute),
      icon: const Icon(Icons.arrow_back),
    );
  }
}
