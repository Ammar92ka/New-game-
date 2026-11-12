import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color gold = Color(0xFFC9A227);
  static const Color navy = Color(0xFF0F1F3D);
  static const Color card = Color(0xFF182B4F);
  static const Color cardBorder = Color(0xFF2E4673);
  static const Color muted = Color(0xFFB8C2D6);
  static const Color good = Color(0xFF6FCF97);
  static const Color bad = Color(0xFFF0868A);
  static const Color goodBg = Color(0x336FCF97);
  static const Color badBg = Color(0x33F0868A);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.gold,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.navy,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
  );
}
