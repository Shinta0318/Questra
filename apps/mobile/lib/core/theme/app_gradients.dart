import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppGradients {
  static const adventure = LinearGradient(
    colors: [AppColors.deepNavy, AppColors.midnightNavy, AppColors.cosmicBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const premium = LinearGradient(
    colors: [AppColors.warmGold, AppColors.gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glass = LinearGradient(
    colors: [Color(0xF7FFFFFF), Color(0xDDF4F7FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
