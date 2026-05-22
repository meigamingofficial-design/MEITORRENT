import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────
// Meitorrent Design System — Japanese Sumi-e Parchment Theme
//
// Palette extracted from the icon:
//   • Background  : #FAF6EE  (warm ivory parchment)
//   • Surface     : #FDF9F2  (soft paper white)
//   • Primary     : #D63031  (crimson rising-sun red)
//   • Ink/Text    : #1A1A1A  (sumi-e charcoal black)
//   • Secondary   : #27AE60  (bamboo green — seeding)
//   • Amber/Warn  : #D35400  (autumn orange — paused)
//   • Error       : #C0392B  (deep crimson — errors)
// ─────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // ── Traditional Japanese Palette (Nippon Colors) ────────────────
  static const _shuRed = Color(0xFFD63031); // Traditional Japanese Crimson Red
  static const _sumizome = Color(0xFF1C1C1C); // Ink Black (Sumizome)
  static const _torinoko = Color(
    0xFFF9F6F0,
  ); // Warm Washi Parchment Ivory (from user painting background)
  static const _kumen = Color(0xFFFFFDF9); // Soft Clean Paper White
  static const _takeGreen = Color(0xFF316745); // Bamboo Green (Take-gaki)
  static const _yamabuki = Color(0xFFFFB11B); // Golden Yellow (Yamabuki)
  static const _beni = Color(
    0xFFB71C1C,
  ); // Deep Traditional Blossom Crimson / Dark Scarlet
  static const _charcoal = Color(0xFF5D5D5D); // Charcoal Gray
  static const _paperBorder = Color(0xFFE2D7C7); // Soft Warm Washi Paper Edge

  // Private legacy aliases
  static const _crimson = _shuRed;
  static const _paperWhite = _kumen;
  static const _inkBlack = _sumizome;
  static const _inkGrey = _charcoal;

  // ── Dark palette (Night Ink Aesthetic) ──────────────────────────
  static const _darkInk = Color(0xFF141517); // Midnight Ink (Background)
  static const _darkSurface = Color(0xFF1F2023); // Soot Gray (Surface/Cards)
  static const _riceWhite = Color(
    0xFFE5E2D9,
  ); // Rice Paper White (Primary Text)
  static const _charcoalFaded = Color(0xFF8A8A8A); // Faded Ink (Secondary Text)
  static const _darkBorder = Color(0xFF2C2D33); // Deep Paper Edge
  static const _darkInput = Color(0xFF1A1B1E); // Input Fill (Dark)
  static const _hankoRedDark = Color(
    0xFFB71C1C,
  ); // Deep Blossom Crimson in Dark

  // ── Light Color Scheme ──────────────────────────────────────
  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: _shuRed,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDADA),
    onPrimaryContainer: _beni,
    secondary: _takeGreen,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD4EDDA),
    onSecondaryContainer: Color(0xFF145A32),
    tertiary: _yamabuki,
    onTertiary: _sumizome,
    tertiaryContainer: Color(0xFFFFE4CC),
    onTertiaryContainer: Color(0xFF7B3100),
    error: _beni,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: _beni,
    surface: _kumen,
    onSurface: _sumizome,
    surfaceContainerHighest: _paperBorder,
    outline: Color(0xFFCCC4BA),
    outlineVariant: _paperBorder,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _sumizome,
    onInverseSurface: _torinoko,
    inversePrimary: Color(0xFFFFB3B3),
  );

  // ── Dark Color Scheme ───────────────────────────────────────
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _shuRed,
    onPrimary: Colors.white,
    primaryContainer: _hankoRedDark,
    onPrimaryContainer: Colors.white,
    secondary: _takeGreen,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF145A32),
    onSecondaryContainer: Color(0xFFD4EDDA),
    tertiary: _yamabuki,
    onTertiary: _darkInk,
    tertiaryContainer: Color(0xFF7B3100),
    onTertiaryContainer: Color(0xFFFFE4CC),
    error: _beni,
    onError: Colors.white,
    errorContainer: _beni,
    onErrorContainer: Colors.white,
    surface: _darkSurface,
    onSurface: _riceWhite,
    surfaceContainerHighest: _darkBorder,
    outline: _charcoalFaded,
    outlineVariant: _darkBorder,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _torinoko,
    onInverseSurface: _sumizome,
    inversePrimary: _shuRed,
  );

  // ── Public ThemeData ──────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: Colors.transparent,

      // Outfit for UI, Shippori Mincho for headers
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: _sumizome,
          displayColor: _sumizome,
        ),
      ),

      // ── Card (Handmade Paper Style) ───────────────────────────
      cardTheme: CardThemeData(
        color: _kumen,
        elevation: 2,
        shadowColor: _sumizome.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _paperBorder, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ── AppBar (Calligraphic Style) ───────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.dark, // Dark status bar icons (time, battery, etc.)
          statusBarBrightness: Brightness.light, // For iOS status bar
          systemNavigationBarColor:
              _torinoko, // Match soft light parchment background
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.shipporiMincho(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _sumizome,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _sumizome),
      ),

      // ── FAB (Hanko Stamp Style) ───────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _shuRed,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            12,
          ), // Squares off slightly like a stamp
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _shuRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.shipporiMincho(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCCC4BA)),
          foregroundColor: _inkGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _inkGrey,
        ),
      ),

      // ── Input ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4EDE0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDDD5C8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _crimson, width: 1.5),
        ),
        hintStyle: TextStyle(color: _inkBlack.withValues(alpha: 0.35)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _inkBlack,
        contentTextStyle: GoogleFonts.outfit(color: const Color(0xFFFAF6EE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Divider ───────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E0D4),
        thickness: 1,
      ),

      // ── Switch ────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _crimson
              : const Color(0xFFCCC4BA),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _crimson.withValues(alpha: 0.25)
              : const Color(0xFFE8E0D4),
        ),
      ),

      // ── Popup Menu ────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: _paperWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E0D4)),
        ),
        elevation: 4,
        shadowColor: Colors.black12,
      ),

      // ── Dialog ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: _paperWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
      ),

      // ── Progress Indicator ────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _crimson,
      ),
    );
  }

  // ── Dark ThemeData ───────────────────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkScheme,
      scaffoldBackgroundColor: _darkInk,

      // Outfit for UI, Shippori Mincho for headers
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: _riceWhite,
          displayColor: _riceWhite,
        ),
      ),

      // ── Card (Dark Paper Style) ───────────────────────────────
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0, // Flat with borders for dark mode
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _darkBorder, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ── AppBar (Dark Calligraphic) ────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Brightness.light, // Light status bar icons (time, battery, etc.)
          statusBarBrightness: Brightness.dark, // For iOS status bar
          systemNavigationBarColor: _darkInk, // Match midnight ink background
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.shipporiMincho(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _riceWhite,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _riceWhite),
      ),

      // ── FAB (Dark Hanko Stamp) ────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _shuRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _shuRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.shipporiMincho(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),

      // ── Outlined Button ───────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _darkBorder),
          foregroundColor: _charcoalFaded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _charcoalFaded,
        ),
      ),

      // ── Input (Dark Ink) ──────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _shuRed, width: 1.5),
        ),
        hintStyle: TextStyle(color: _riceWhite.withValues(alpha: 0.35)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: GoogleFonts.outfit(color: _riceWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Divider ───────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
      ),

      // ── Switch ────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? _shuRed : _charcoalFaded,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? _shuRed.withValues(alpha: 0.25)
              : _darkBorder,
        ),
      ),

      // ── Popup Menu ────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder),
        ),
        elevation: 8,
      ),

      // ── Dialog ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
      ),

      // ── Progress Indicator ────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _shuRed,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Simplified AppColors
// ─────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Theme-Aware Semantic Colors ──────────────────────────────────
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? kumen
      : (Theme.of(context).cardTheme.color ?? darkSurface);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? torinoko
      : darkBackground;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? sumizome
      : const Color(0xFFE5E2D9); // Rice White

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? charcoal
      : const Color(0xFF8A8A8A); // Faded Ink

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? paperBorder
      : const Color(0xFF2C2D33); // Dark Border

  // ── Static Palette ───────────────────────────────────────────────
  static const torinoko = Color(
    0xFFF9F6F0,
  ); // Warm Washi Parchment Ivory (from user painting background)
  static const kumen = Color(0xFFFFFDF9); // Soft Clean Paper White
  static const darkBackground = Color(0xFF141517); // dark background
  static const darkSurface = Color(0xFF1F2023); // Soot Black (Surface/Cards)
  static const boneWhite = Color(0xFFE5E2D9);

  // Legacy aliases to fix compilation
  static const parchment = torinoko;
  static const paperWhite = kumen;
  static const inkBlack = sumizome;
  static const inkGrey = charcoal;
  static const inkFaded = paperBorder;

  static Color inputFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFF4EDE0)
      : const Color(0xFF1A1B1E);

  static const sumizome = Color(0xFF1C1C1C); // primary text (light)
  static const charcoal = Color(0xFF5D5D5D); // secondary text (light)
  static const paperBorder = Color(0xFFE2D7C7); // borders / dividers (light)

  // ── Torrent state colours (Static across themes) ──────────────────
  static const downloading = Color(
    0xFFD63031,
  ); // Traditional Japanese Crimson Red
  static const downloadingDark = Color(
    0xFFB71C1C,
  ); // Deep Traditional Blossom Crimson / Dark Scarlet
  static const seeding = Color(0xFF316745); // Take Green
  static const paused = Color(0xFFD35400); // Autumn Orange
  static const error = Color(0xFFB71C1C); // Deep Traditional Blossom Crimson
  static const finished = Color(0xFF145A32); // Deep Take Green
  static const unknown = Color(0xFF8A8A8A); // Faded Ink
  static const metadata = Color(0xFF5D5D5D); // Charcoal
  static const checking = Color(0xFF5D5D5D);
}

// ─────────────────────────────────────────────────────────────────
// Gradient definitions
// ─────────────────────────────────────────────────────────────────
class AppGradients {
  AppGradients._();

  /// Primary Crimson Red gradient (FAB, CTAs).
  static const primary = LinearGradient(
    colors: [Color(0xFFD63031), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Seeding gradient — Take Green.
  static const seeding = LinearGradient(
    colors: [Color(0xFF316745), Color(0xFF145A32)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Error gradient.
  static const error = LinearGradient(
    colors: [Color(0xFFB71C1C), Color(0xFF800020)], // Deep Crimson to Burgundy
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Paused gradient.
  static const paused = LinearGradient(
    colors: [Color(0xFFD35400), Color(0xFF7B3100)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle paper card tint.
  static const cardSurface = LinearGradient(
    colors: [Color(0x08D63031), Color(0x041C1C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Active selection / border gradient.
  static const activeBorder = LinearGradient(
    colors: [Color(0x40D63031), Color(0x20B71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
