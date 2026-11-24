import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData dark() {
    const accent = Color(0xFF6C63FF);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D12),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        background: const Color(0xFF0D0D12),
        surface: const Color(0xFF16161F),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D12),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardTheme(
        color: Color(0xFF16161F),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      useMaterial3: true,
    );
  }
}