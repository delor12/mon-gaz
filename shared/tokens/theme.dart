import 'package:flutter/material.dart';

/// SmartGas Design System - Shared Tokens (Dart)
/// Source of truth: shared/tokens/theme.json
class SharedThemeTokens {
  // Primary Palette
  static const Color bluePrimary = Color(0xFF0A2A6B);
  static const Color blueDeep = Color(0xFF061A45);
  static const Color blueLight = Color(0xFF1E5EFF);
  static const Color blueSurface = Color(0xFF0D3585);
  static const Color blueGlass = Color(0xA60A2A6B);

  // Accents
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5D76E);
  static const Color goldDark = Color(0xFF997A15);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color yellowHover = Color(0xFFE6C200);

  // Status Colors
  static const Color alertCritical = Color(0xFFE5383B);
  static const Color alertWarning = Color(0xFFFFD60A);
  static const Color alertInfo = Color(0xFF1E5EFF);
  static const Color success = Color(0xFF10B981);

  // Text Colors
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFA2B4D6);
  static const Color textMuted = Color(0xFF6C82A6);
  static const Color textInverse = Color(0xFF061A45);

  // Borders
  static const Color borderSubtle = Color(0x40D4AF37);
  static const Color borderGold = Color(0xFFD4AF37);

  // Gradients
  static const LinearGradient goldGaugeGradient = LinearGradient(
    colors: [goldLight, gold],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient surfaceDeepGradient = LinearGradient(
    colors: [bluePrimary, blueDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient alertCriticalGradient = LinearGradient(
    colors: [alertCritical, Color(0xFF8F1D20)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
