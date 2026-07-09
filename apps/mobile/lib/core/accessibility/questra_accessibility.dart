import 'package:flutter/material.dart';

abstract final class QuestraAccessibility {
  static const double minTapTarget = kMinInteractiveDimension;
  static const double comfortableTapTarget = 56;

  static const BoxConstraints minTapTargetConstraints = BoxConstraints(
    minWidth: minTapTarget,
    minHeight: minTapTarget,
  );

  static const BoxConstraints comfortableTapTargetConstraints = BoxConstraints(
    minWidth: comfortableTapTarget,
    minHeight: comfortableTapTarget,
  );
}
