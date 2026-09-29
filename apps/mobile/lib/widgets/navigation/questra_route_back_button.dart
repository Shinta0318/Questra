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
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    final canPop = router?.canPop() ?? navigator?.canPop() ?? false;
    return IconButton(
      tooltip: canPop ? '戻る' : fallbackTooltip,
      onPressed: () {
        if (router != null) {
          if (router.canPop()) {
            router.pop();
          } else {
            router.go(fallbackRoute);
          }
          return;
        }
        navigator?.maybePop();
      },
      icon: const Icon(Icons.arrow_back),
    );
  }
}
