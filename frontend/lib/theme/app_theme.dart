import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Cybersecurity Color Palette
  static const Color darkBackground = Color(0xFF0A0F1D);
  static const Color cardSurface = Color(0xFF141E33);
  static const Color cardBorder = Color(0xFF213254);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color dangerRed = Color(0xFFFF3366);
  static const Color warningAmber = Color(0xFFFFB800);
  static const Color safeGreen = Color(0xFF00E676);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme);

    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        surface: cardSurface,
        error: dangerRed,
        onPrimary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: cyanAccent),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanAccent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cyanAccent,
          side: const BorderSide(color: cyanAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.outfit(color: textPrimary),
        bodyMedium: GoogleFonts.outfit(color: textSecondary),
      ),
    );
  }
}
