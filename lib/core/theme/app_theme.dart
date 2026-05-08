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

  // ── Raw palette constants ──────────────────────────────────────
  static const _crimson = Color(0xFFD63031); // Rising-sun red
  static const _parchment = Color(0xFFFAF6EE); // Ivory canvas
  static const _paperWhite = Color(0xFFFDF5E6); // Warm parchment for cards
  static const _inkBlack = Color(0xFF1A1A1A); // Sumi-e ink
  static const _bamboo = Color(0xFF27AE60); // Bamboo green
  static const _autumnOrange = Color(0xFFD35400); // Autumn orange
  static const _deepCrimson = Color(0xFFC0392B); // Error red
  static const _inkGrey = Color(0xFF5D5D5D); // Secondary text
  static const _inkFaded = Color(0xFFE8E0D4); // Dividers / borders

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
    primary: _crimson,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDADA),
    onPrimaryContainer: Color(0xFF8B0000),
    secondary: _bamboo,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD4EDDA),
    onSecondaryContainer: Color(0xFF145A32),
    tertiary: _autumnOrange,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE4CC),
    onTertiaryContainer: Color(0xFF7B3100),
    error: _deepCrimson,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF8B0000),
    surface: _paperWhite,
    onSurface: _inkBlack,
    surfaceContainerHighest: _inkFaded,
    outline: Color(0xFFCCC4BA),
    outlineVariant: Color(0xFFE8E0D4),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _inkBlack,
    onInverseSurface: _parchment,
    inversePrimary: Color(0xFFFFB3B3),
  );

  // ── Public ThemeData ──────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: _parchment,

      // Outfit font — modern yet warm
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: _inkBlack,
              displayColor: _inkBlack,
            ),
      ),

      // ── Card ──────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: _paperWhite,
        elevation: 3,
        shadowColor: _inkBlack.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE8E0D4), width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // ── AppBar ────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: _inkBlack,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: _inkBlack),
      ),

      // ── FAB ───────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _crimson,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Elevated Button ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _crimson,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
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
          ? paperWhite
          : (Theme.of(context).cardTheme.color ?? darkSurface);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? parchment
          : darkBackground;

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? inkBlack
          : const Color(0xFFE0E0E0);

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? inkGrey
          : const Color(0xFF9E9E9E);

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? inkFaded
          : const Color(0xFF2C2C2C);

  // ── Static Palette ───────────────────────────────────────────────
  static const parchment = Color(0xFFFAF6EE); // light background
  static const paperWhite = Color(0xFFFDF9F2); // light surface
  static const darkBackground = Color(0xFF0D0D0D); // dark background
  static const darkSurface = Color(0xFF161616); // Soot Black (Surface/Cards)
  static const boneWhite = Color(0xFFE5E2D9);
  static const fadedInk = Color(0xFF8A8A8A);

  static Color inputFill(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF4EDE0)
          : const Color(0xFF1F1F1F);

  static const inkBlack = Color(0xFF1A1A1A); // primary text (light)
  static const inkGrey = Color(0xFF5D5D5D); // secondary text (light)
  static const inkFaded = Color(0xFFE8E0D4); // borders / dividers (light)

  // ── Torrent state colours (Static across themes) ──────────────────
  static const downloading = Color(0xFFD63031); // crimson red
  static const downloadingDark = Color(0xFFC23616); // deep crimson
  static const seeding = Color(0xFF27AE60); // bamboo green
  static const paused = Color(0xFFD35400); // autumn orange
  static const error = Color(0xFFC0392B); // deep crimson
  static const finished = Color(0xFF1E8449); // forest green
  static const unknown = Color(0xFF8E8E8E); // slate grey
  static const metadata = Color(0xFF9E9E9E);
  static const checking = Color(0xFF9E9E9E);
}

// ─────────────────────────────────────────────────────────────────
// Gradient definitions
// ─────────────────────────────────────────────────────────────────
class AppGradients {
  AppGradients._();

  /// Primary crimson gradient (FAB, CTAs).
  static const primary = LinearGradient(
    colors: [Color(0xFFE84118), Color(0xFFC23616)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Seeding gradient — bamboo green.
  static const seeding = LinearGradient(
    colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Error gradient.
  static const error = LinearGradient(
    colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Paused gradient — autumn orange.
  static const paused = LinearGradient(
    colors: [Color(0xFFF39C12), Color(0xFFD35400)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle crimson card tint.
  static const cardSurface = LinearGradient(
    colors: [Color(0x08D63031), Color(0x04C23616)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Active selection / border gradient.
  static const activeBorder = LinearGradient(
    colors: [Color(0x40D63031), Color(0x20C23616)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
