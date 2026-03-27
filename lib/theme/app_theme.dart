import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9AA8FF),
        onPrimary: Color(0xFF001D8B),
        primaryContainer: Color(0xFF8899FF),
        secondary: Color(0xFFBF81FF),
        secondaryContainer: Color(0xFF7701D0),
        tertiary: Color(0xFF6DDDFF),
        error: Color(0xFFFF6E84),
        surface: Color(0xFF0B0E15),
        surfaceContainerLow: Color(0xFF10131B),
        surfaceContainer: Color(0xFF161A22),
        surfaceContainerHigh: Color(0xFF1C2029),
        surfaceContainerHighest: Color(0xFF212630),
        onSurface: Color(0xFFF2F3FD),
        onSurfaceVariant: Color(0xFFA9ABB4),
        outline: Color(0xFF73757E),
        outlineVariant: Color(0xFF454850),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0E15),
    );

    return base.copyWith(
      textTheme: TextTheme(
        displayLarge: GoogleFonts.chakraPetch(
            fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: -1.5),
        displayMedium: GoogleFonts.chakraPetch(
            fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: -1),
        displaySmall: GoogleFonts.chakraPetch(
            fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0),
        headlineLarge: GoogleFonts.chakraPetch(
            fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0),
        headlineMedium: GoogleFonts.chakraPetch(
            fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0),
        titleLarge: GoogleFonts.chakraPetch(
            fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0),
        bodyLarge: GoogleFonts.chakraPetch(
            fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
        bodyMedium: GoogleFonts.chakraPetch(
            fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
        labelLarge: GoogleFonts.chakraPetch(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.25,
            color: const Color(0xFFF2F3FD).withValues(alpha: 0.6)),
        labelMedium: GoogleFonts.chakraPetch(
            fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        labelSmall: GoogleFonts.chakraPetch(
            fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161A22),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C2029),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF454850)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFF1C2029),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.chakraPetch(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: const Color(0xFF9AA8FF));
          }
          return GoogleFonts.chakraPetch(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: const Color(0xFFF2F3FD).withValues(alpha: 0.4));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF9AA8FF), size: 24);
          }
          return IconThemeData(
              color: const Color(0xFFF2F3FD).withValues(alpha: 0.4), size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9AA8FF),
          foregroundColor: const Color(0xFF001D8B),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          textStyle:
              GoogleFonts.chakraPetch(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
