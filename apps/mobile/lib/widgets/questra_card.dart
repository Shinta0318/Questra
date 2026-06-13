import 'package:flutter/material.dart';

import '../core/theme/questra_colors.dart';

class QuestraCard extends StatelessWidget {
  const QuestraCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }
}
