import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Colori premium
  static const Color primary = Color(0xFF0288D1);
  static const Color primaryLight = Color(0xFF4FC3F7);
  static const Color primaryDark = Color(0xFF01579B);
  static const Color accent = Color(0xFFFFB300);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF4A4A6A);
  static const Color background = Color(0xFFF0F4FF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF90A4AE);
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF1744);

  // Gradiente principale
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0288D1), Color(0xFF01579B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF01579B), Color(0xFF0288D1), Color(0xFF4FC3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: background,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: white,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            elevation: 4,
            shadowColor: primary.withValues(alpha: 0.4),
            textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 15),
          ),
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primary, width: 2)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: grey.withValues(alpha: 0.2))),
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', color: AppTheme.textMedium),
          hintStyle: TextStyle(
              fontFamily: 'Poppins', color: grey.withValues(alpha: 0.7)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              color: textDark),
          titleLarge: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: textDark),
          titleMedium: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              color: textDark),
          bodyLarge: TextStyle(fontFamily: 'Poppins', color: textMedium),
          bodyMedium: TextStyle(fontFamily: 'Poppins', color: textMedium),
        ),
      );
}
