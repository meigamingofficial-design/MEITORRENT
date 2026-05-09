import 'package:flutter/material.dart';
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
  static const _shuRed = Color(0xFFE83929); // Vermilion (Shu-iro)
  static const _sumizome = Color(0xFF1C1C1C); // Ink Black (Sumizome)
  static const _torinoko = Color(0xFFF9F1E1); // Paper/Eggshell (Torinoko)
  static const _kumen = Color(0xFFFDF9F2); // Ivory Parchment
  static const _takeGreen = Color(0xFF316745); // Bamboo Green (Take-gaki)
  static const _yamabuki = Color(0xFFFFB11B); // Golden Yellow (Yamabuki)
  static const _beni = Color(0xFFB7282E); // Deep Madder Red (Beni-iro)
  static const _charcoal = Color(0xFF5D5D5D); // Charcoal Gray
  static const _paperBorder = Color(0xFFE8E0D4); // Soft Paper Edge

  // Private legacy aliases
  static const _crimson = _shuRed;
  static const _paperWhite = _kumen;
  static const _inkBlack = _sumizome;
  static const _bamboo = _takeGreen;
  static const _deepCrimson = _beni;
  static const _inkGrey = _charcoal;

  // ── Dark palette ───────────────────────────────────────────────
  static const _darkInk = Color(0xFF0D0D0D); // Midnight Ink (Background)
  static const _darkSurface = Color(0xFF161616); // Soot Black (Surface/Cards)
  static const _boneWhite = Color(0xFFE5E2D9); // Bone White (Primary Text)
  static const _fadedInk = Color(0xFF8A8A8A); // Faded Ink (Secondary Text)
  static const _darkBorder = Color(0xFF222222); // Deep Border
  static const _darkInput = Color(0xFF1F1F1F); // Input Fill (Dark)

  // ── Color Scheme ──────────────────────────────────────────────
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

  // ── Public ThemeData ──────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: _torinoko,

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
          borderRadius: BorderRadius.circular(12), // Squares off slightly like a stamp
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  /// Dark Sumi-e Theme — Deep Ink & Bone White
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _crimson,
        secondary: _bamboo,
        surface: _darkInk,
        onSurface: _boneWhite,
        surfaceContainer: _darkSurface,
        onSurfaceVariant: _fadedInk,
        outline: _darkBorder,
        error: _deepCrimson,
      ),
      scaffoldBackgroundColor: _darkInk,
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme()).copyWith(
        displayLarge:
            const TextStyle(color: _boneWhite, fontWeight: FontWeight.w800),
        titleLarge:
            const TextStyle(color: _boneWhite, fontWeight: FontWeight.w700),
        bodyMedium: const TextStyle(color: _boneWhite),
        bodySmall: const TextStyle(color: _fadedInk),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _boneWhite),
        titleTextStyle: TextStyle(
          color: _boneWhite,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: _fadedInk),
      ),
      dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Semantic colors — torrent state accent colours
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
          : const Color(0xFFE0E0E0);

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? charcoal
          : const Color(0xFF9E9E9E);

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? paperBorder
          : const Color(0xFF2C2C2C);

  // ── Static Palette ───────────────────────────────────────────────
  static const torinoko = Color(0xFFF9F1E1); // light background
  static const kumen = Color(0xFFFDF9F2); // light surface
  static const darkBackground = Color(0xFF0D0D0D); // dark background
  static const darkSurface = Color(0xFF161616); // Soot Black (Surface/Cards)
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
          : const Color(0xFF1F1F1F);

  static const sumizome = Color(0xFF1C1C1C); // primary text (light)
  static const charcoal = Color(0xFF5D5D5D); // secondary text (light)
  static const paperBorder = Color(0xFFE8E0D4); // borders / dividers (light)

  // ── Torrent state colours (Static across themes) ──────────────────
  static const downloading = Color(0xFFE83929); // Shu Red
  static const downloadingDark = Color(0xFFB7282E); // Beni Red
  static const seeding = Color(0xFF316745); // Take Green
  static const paused = Color(0xFFD35400); // Autumn Orange
  static const error = Color(0xFFB7282E); // Beni Red
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

  /// Primary Shu red gradient (FAB, CTAs).
  static const primary = LinearGradient(
    colors: [Color(0xFFE83929), Color(0xFFB7282E)],
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
    colors: [Color(0xFFB7282E), Color(0xFF8B0000)],
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
    colors: [Color(0x08E83929), Color(0x041C1C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Active selection / border gradient.
  static const activeBorder = LinearGradient(
    colors: [Color(0x40E83929), Color(0x20B7282E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
