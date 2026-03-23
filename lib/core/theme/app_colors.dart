import 'package:flutter/material.dart';

/// LingoDev renk paleti
/// Ana renk: Lila (#A06CD5)
class AppColors {
  AppColors._();

  // ── Ana Renkler ──────────────────────────────────────────
  static const Color primary = Color(0xFFA06CD5);
  static const Color primaryLight = Color(0xFFC9A7EB);
  static const Color primaryDark = Color(0xFF7B4EAA);

  // ── Arka Plan Renkleri ───────────────────────────────────
  static const Color background = Color(0xFF0F0E17);
  static const Color surface = Color(0xFF1A1829);
  static const Color surfaceLight = Color(0xFF252336);

  // ── Metin Renkleri ───────────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0ADCA);
  static const Color textHint = Color(0xFF6B6890);

  // ── Durum Renkleri ───────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);

  // ── Gradient ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFA06CD5), Color(0xFF6C4AB6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F0E17), Color(0xFF1A1829), Color(0xFF0F0E17)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
