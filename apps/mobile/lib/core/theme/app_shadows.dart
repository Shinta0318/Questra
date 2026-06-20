import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  static List<BoxShadow> get glassCard => [
    BoxShadow(
      color: AppColors.deepNavy.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: AppColors.skyBlue.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: AppColors.gold.withValues(alpha: 0.24),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}
