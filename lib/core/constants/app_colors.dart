import 'package:flutter/material.dart';

class AppColors {
  // Primary Purple Palette (Matching UI screens 01 to 15)
  static const Color primary = Color(0xFF6B2D9B);
  static const Color primaryDark = Color(0xFF4C1D73);
  static const Color primaryLight = Color(0xFF8B3DCC);
  static const Color primaryAccent = Color(0xFF7C3AED);

  // Backgrounds & Surface
  static const Color backgroundDark = Color(0xFF0D0914);
  static const Color backgroundCardDark = Color(0xFF191228);
  static const Color backgroundLight = Color(0xFFF7F5FC);
  static const Color cardLight = Colors.white;
  static const Color surfaceGrey = Color(0xFFF3F4F6);

  // Text Colors
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Accent Colors
  static const Color greenSuccess = Color(0xFF10B981);
  static const Color orangeWarning = Color(0xFFF59E0B);
  static const Color redError = Color(0xFFEF4444);
  static const Color blueInfo = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5E258D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [Color(0xFF1A102F), Color(0xFF0F0C20)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF0F081D), Color(0xFF3B155B), Color(0xFF6B2D9B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
