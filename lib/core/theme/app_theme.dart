import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Meitorrent design system — dark premium theme.
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF00B894);
  static const _backgroundColor = Color(0xFF080C14);
  static const _surfaceColor = Color(0xFF121826);

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    surface: _surfaceColor,
    onSurface: const Color(0xFFF0F4F8),
    surfaceContainerHighest: const Color(0xFF1B2333),
    primary: _seedColor,
    secondary: const Color(0xFF2ECC71),
    error: const Color(0xFFEF4444),
    tertiary: const Color(0xFF55EFC4),
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: _backgroundColor,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFF0F4F8),
          displayColor: const Color(0xFFF0F4F8),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFF0F4F8),
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF0F4F8)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _seedColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121826),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _seedColor, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Colors.white30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B2333),
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  static const downloading = Color(0xFF00B894);
  static const seeding = Color(0xFF2ECC71);
  static const paused = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const finished = Color(0xFF55EFC4);
  static const unknown = Color(0xFF6B7280);
  static const metadata = Color(0xFFBDC3C7);
  static const checking = Color(0xFFBDC3C7);
}

/// Reusable gradient definitions for the premium glassmorphism UI.
class AppGradients {
  AppGradients._();

  /// Primary Emerald → Deep Mint gradient.
  static const primary = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF00A382)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Seeding gradient — Green → Soft Mint.
  static const seeding = LinearGradient(
    colors: [Color(0xFF00B894), Color(0xFF55EFC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Error gradient — Red → Deep Red.
  static const error = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Paused gradient — Amber → Orange.
  static const paused = LinearGradient(
    colors: [Color(0xFFFFB86C), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glassmorphism card surface with subtle Emerald tint.
  static const cardSurface = LinearGradient(
    colors: [Color(0x1A00B894), Color(0x0A00A382)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Active glow border gradient.
  static const activeBorder = LinearGradient(
    colors: [Color(0x8000B894), Color(0x4055EFC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

