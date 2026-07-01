import 'dart:ui';

import 'package:flutter/material.dart';

class QuestraScrollBehavior extends MaterialScrollBehavior {
  const QuestraScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return switch (getPlatform(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      _ => const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    };
  }
}
