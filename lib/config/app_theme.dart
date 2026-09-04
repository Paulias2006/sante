import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.g700,
        secondary: AppColors.g500,
        surface: Color(0xFFFFFFFF),
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.s50,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.syne(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.s800,
        ),
        displayMedium: GoogleFonts.syne(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.s800,
        ),
        headlineLarge: GoogleFonts.syne(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.s800,
        ),
        headlineMedium: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.s800,
        ),
        headlineSmall: GoogleFonts.syne(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.s800,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.s800,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.s800,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.s800,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: AppColors.s600,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.s400,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.s800,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.s400,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.s400,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.s800,
        shadowColor: Colors.black.withAlpha(18),
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: AppColors.s800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: AppColors.s100),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.s200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.s200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.g500, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      buttonTheme: const ButtonThemeData(height: 40, minWidth: 80),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.g600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.s600,
          side: const BorderSide(color: AppColors.s200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
