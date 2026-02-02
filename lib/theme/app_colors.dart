import 'package:flutter/material.dart';

class AppColors {
  // Cores principais do tema
  static const Color midnightBlue = Color(0xFF0D1B2A);
  static const Color deepBlue = Color(0xFF1B263B);
  static const Color navyBlue = Color(0xFF415A77);
  static const Color babyBlue = Color(0xFF89C2D9);
  static const Color lightBlue = Color(0xFFA9D6E5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color starYellow = Color(0xFFFFF3B0);
  
  // Cores de background
  static const Color backgroundDark = Color(0xFF0A1628);
  static const Color cardDark = Color(0xFF152238);
  static const Color surfaceDark = Color(0xFF1E3A5F);
  
  // Cores de texto
  static const Color textPrimary = Color(0xFFE8F4F8);
  static const Color textSecondary = Color(0xFFB8D4E3);
  static const Color textMuted = Color(0xFF6B8CA4);
  
  // Cores de status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF42A5F5);
  
  // Gradientes
  static const LinearGradient nightSkyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D1B2A),
      Color(0xFF1B263B),
      Color(0xFF1E3A5F),
    ],
  );
  
  static const LinearGradient roadGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2C3E50),
      Color(0xFF34495E),
    ],
  );
  
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      babyBlue,
      lightBlue,
    ],
  );
}
