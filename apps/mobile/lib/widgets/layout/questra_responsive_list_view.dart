import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/questra_responsive_layout.dart';

class QuestraResponsiveListView extends StatefulWidget {
  const QuestraResponsiveListView({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth,
    this.controller,
    this.onRefresh,
    this.showScrollbar = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double? maxContentWidth;
  final ScrollController? controller;
  final RefreshCallback? onRefresh;
  final bool showScrollbar;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  State<QuestraResponsiveListView> createState() =>
      _QuestraResponsiveListViewState();
}

class _QuestraResponsiveListViewState extends State<QuestraResponsiveListView> {
  final _internalController = ScrollController();

  ScrollController get _controller => widget.controller ?? _internalController;

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = QuestraLayoutSpec.fromWidth(availableWidth);
        final resolvedPadding = widget.padding.resolve(
          Directionality.of(context),
        );
        final horizontalPadding = layout.horizontalPadding;
        final effectivePadding = EdgeInsets.fromLTRB(
          math.max(resolvedPadding.left, horizontalPadding),
          resolvedPadding.top,
          math.max(resolvedPadding.right, horizontalPadding),
          resolvedPadding.bottom,
        );
        final contentWidth = math.min(
          availableWidth,
          widget.maxContentWidth ?? layout.maxContentWidth,
        );

        final listView = ListView(
          controller: _controller,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          padding: effectivePadding,
          children: widget.children,
        );
        Widget scrollable = widget.onRefresh == null
            ? listView
            : RefreshIndicator(onRefresh: widget.onRefresh!, child: listView);
        if (widget.showScrollbar) {
          scrollable = Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            interactive: true,
            child: scrollable,
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: contentWidth, child: scrollable),
        );
      },
    );
  }
}
