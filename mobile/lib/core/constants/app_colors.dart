import 'package:flutter/material.dart';

class AppColors {
  // Palette Principale Bleu & Or
  static const Color bluePrimary = Color(0xFF0A2A6B);
  static const Color blueDeep = Color(0xFF061A45);
  static const Color blueLight = Color(0xFF1E5EFF);
  static const Color blueSurface = Color(0xFF0D3585);
  static const Color blueGlass = Color(0xA60A2A6B);

  // Accents Or & Jaune
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5D76E);
  static const Color goldDark = Color(0xFF997A15);
  static const Color yellow = Color(0xFFFFD60A);
  static const Color yellowHover = Color(0xFFE6C200);

  // Statuts & Sécurité
  static const Color alertRed = Color(0xFFE5383B);
  static const Color alertRedDeep = Color(0xFF8F1D20);
  static const Color greenSuccess = Color(0xFF10B981);

  // Typographie & Surfaces
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFA2B4D6);
  static const Color textMuted = Color(0xFF6C82A6);

  // Bordures
  static const Color borderGold = Color(0xFFD4AF37);
  static const Color borderSubtle = Color(0x40D4AF37);

  // Dégradés
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
    colors: [alertRed, alertRedDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
