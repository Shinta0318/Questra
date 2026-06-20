import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get glassCard => BorderRadius.circular(xl);
  static BorderRadius get button => BorderRadius.circular(md);
}
