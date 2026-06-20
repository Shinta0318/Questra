import 'package:flutter/material.dart';

abstract final class AppColors {
  static const deepNavy = Color(0xFF071426);
  static const midnightNavy = Color(0xFF0D213A);
  static const cosmicBlue = Color(0xFF1C6DD0);
  static const nebulaBlue = Color(0xFF144A93);
  static const skyBlue = Color(0xFF5EA7FF);
  static const auroraTeal = Color(0xFF2DD4BF);
  static const gold = Color(0xFFFFC857);
  static const warmGold = Color(0xFFFFD879);
  static const parchment = Color(0xFFF7F2E8);
  static const cloud = Color(0xFFF4F7FB);
  static const glass = Color(0xEFFFFFFF);
  static const slate = Color(0xFF50647C);
  static const white = Color(0xFFFFFFFF);

  static const adventureGradient = LinearGradient(
    colors: [deepNavy, midnightNavy, cosmicBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const premiumGradient = LinearGradient(
    colors: [warmGold, gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassGradient = LinearGradient(
    colors: [Color(0xF7FFFFFF), Color(0xDDF4F7FB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
