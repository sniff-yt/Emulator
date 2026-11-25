import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0A0D1A);
  static const surface = Color(0xFF131729);
  static const surface2 = Color(0xFF1B2038);
  static const stroke = Color(0x1FFFFFFF);
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF22D3EE);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
  static const text = Color(0xFFEDEFFC);
  static const muted = Color(0xFF8D93B5);
  static const gradient = LinearGradient(colors: [violet, cyan], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.violet,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        error: AppColors.red,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
      ),
      cardTheme: const CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.stroke),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      sliderTheme: const SliderThemeData(activeTrackColor: AppColors.violet, thumbColor: AppColors.violet),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.violet : AppColors.surface2),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.surface2),
    );
  }
}
