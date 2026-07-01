import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/questra_responsive_layout.dart';

class QuestraResponsiveListView extends StatelessWidget {
  const QuestraResponsiveListView({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth,
    this.controller,
    this.onRefresh,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double? maxContentWidth;
  final ScrollController? controller;
  final RefreshCallback? onRefresh;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = QuestraLayoutSpec.fromWidth(availableWidth);
        final resolvedPadding = padding.resolve(Directionality.of(context));
        final horizontalPadding = layout.horizontalPadding;
        final effectivePadding = EdgeInsets.fromLTRB(
          math.max(resolvedPadding.left, horizontalPadding),
          resolvedPadding.top,
          math.max(resolvedPadding.right, horizontalPadding),
          resolvedPadding.bottom,
        );
        final contentWidth = math.min(
          availableWidth,
          maxContentWidth ?? layout.maxContentWidth,
        );

        final listView = ListView(
          controller: controller,
          keyboardDismissBehavior: keyboardDismissBehavior,
          padding: effectivePadding,
          children: children,
        );

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: onRefresh == null
                ? listView
                : RefreshIndicator(onRefresh: onRefresh!, child: listView),
          ),
        );
      },
    );
  }
}
