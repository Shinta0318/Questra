import 'package:flutter/material.dart';

class QuestraMotion {
  const QuestraMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve gentle = Curves.easeInOutSine;
}
