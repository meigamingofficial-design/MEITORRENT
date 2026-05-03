import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Meitorrent design system — dark premium theme.
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF6C63FF);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF0F0F1A),
    onSurface: const Color(0xFFE8E8F0),
    surfaceContainerHighest: const Color(0xFF1A1A2E),
    primary: _seedColor,
    secondary: const Color(0xFF50FA7B),
    error: const Color(0xFFFF5555),
    tertiary: const Color(0xFFFFB86C),
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFE8E8F0),
          displayColor: const Color(0xFFE8E8F0),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F0F1A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE8E8F0),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8E8F0)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _seedColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252540),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _seedColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Colors.white30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A2E),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white10,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _seedColor
              : Colors.white38,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _seedColor.withValues(alpha: 0.3)
              : Colors.white12,
        ),
      ),
    );
  }
}

/// Semantic color palette — maps TorrentState to accent colors.
class AppColors {
  AppColors._();

  static const downloading = Color(0xFF6C63FF);
  static const seeding = Color(0xFF50FA7B);
  static const paused = Color(0xFFFFB86C);
  static const error = Color(0xFFFF5555);
  static const finished = Color(0xFF8BE9FD);
  static const unknown = Color(0xFFBD93F9);
  static const metadata = Color(0xFFFF79C6);
  static const checking = Color(0xFFF1FA8C);
}

/// Reusable gradient definitions for the premium glassmorphism UI.
class AppGradients {
  AppGradients._();

  /// Primary purple → blue gradient (progress bars, FAB, badges).
  static const primary = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF48B0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Seeding gradient — teal → green.
  static const seeding = LinearGradient(
    colors: [Color(0xFF00D2A0), Color(0xFF50FA7B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Error gradient — red → orange.
  static const error = LinearGradient(
    colors: [Color(0xFFFF5555), Color(0xFFFF8C00)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Paused gradient — amber → orange.
  static const paused = LinearGradient(
    colors: [Color(0xFFFFB86C), Color(0xFFFFD700)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Glassmorphism card surface with subtle purple tint.
  static const cardSurface = LinearGradient(
    colors: [Color(0x1A6C63FF), Color(0x0D48B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Active glow border gradient.
  static const activeBorder = LinearGradient(
    colors: [Color(0x806C63FF), Color(0x8048B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
