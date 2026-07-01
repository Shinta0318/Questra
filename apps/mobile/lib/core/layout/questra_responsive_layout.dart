import 'package:flutter/widgets.dart';

enum QuestraWindowClass { compact, medium, expanded }

abstract final class QuestraBreakpoints {
  static const medium = 600.0;
  static const expanded = 1024.0;
}

class QuestraLayoutSpec {
  const QuestraLayoutSpec({
    required this.windowClass,
    required this.horizontalPadding,
    required this.maxContentWidth,
  });

  factory QuestraLayoutSpec.fromWidth(double width) {
    if (width < QuestraBreakpoints.medium) {
      return QuestraLayoutSpec(
        windowClass: QuestraWindowClass.compact,
        horizontalPadding: width < 360 ? 12 : 16,
        maxContentWidth: width,
      );
    }
    if (width < QuestraBreakpoints.expanded) {
      return const QuestraLayoutSpec(
        windowClass: QuestraWindowClass.medium,
        horizontalPadding: 24,
        maxContentWidth: 760,
      );
    }
    return const QuestraLayoutSpec(
      windowClass: QuestraWindowClass.expanded,
      horizontalPadding: 32,
      maxContentWidth: 960,
    );
  }

  final QuestraWindowClass windowClass;
  final double horizontalPadding;
  final double maxContentWidth;

  bool get isCompact => windowClass == QuestraWindowClass.compact;
  bool get isExpanded => windowClass == QuestraWindowClass.expanded;
}

extension QuestraResponsiveContext on BuildContext {
  QuestraLayoutSpec get questraLayout =>
      QuestraLayoutSpec.fromWidth(MediaQuery.sizeOf(this).width);
}
