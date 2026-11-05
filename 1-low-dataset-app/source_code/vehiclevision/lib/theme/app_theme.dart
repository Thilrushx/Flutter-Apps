import 'package:flutter/material.dart';

// ── Colour palette ──────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color background     = Color(0xFF0D1B2A);
  static const Color backgroundLight = Color(0xFF112236);
  static const Color backgroundDark  = Color(0xFF07111C);
  static const Color surface         = Color(0xFF16293F);
  static const Color surfaceBorder   = Color(0xFF1E3A54);

  static const Color primary      = Color(0xFF1E90FF);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark  = Color(0xFF0D6EBF);

  static const Color error   = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);

  static const Color textPrimary   = Colors.white;
  static const Color textSecondary = Color(0xFF8BAABF);
  static const Color textHint      = Color(0xFF4A6480);
}

// ── Text styles ─────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}
