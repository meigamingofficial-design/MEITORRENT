import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeService — single source of truth for app theme mode.
//
// Usage (in any widget):
//   final themeMode = ref.watch(themeServiceProvider);          // current mode
//   ref.read(themeServiceProvider.notifier).setLight();         // switch light
//   ref.read(themeServiceProvider.notifier).setDark();          // switch dark
//   ref.read(themeServiceProvider.notifier).toggle();           // toggle
//
// In app.dart — just watch this one provider:
//   theme:      AppTheme.light,
//   darkTheme:  AppTheme.dark,
//   themeMode:  ref.watch(themeServiceProvider),
//
// To change the ENTIRE palette, only edit AppColors in app_theme.dart.
// Every screen that uses AppColors.* or Theme.of(context) will update
// automatically — no screen-by-screen changes needed.
// ─────────────────────────────────────────────────────────────────────────────

const _kThemeModeKey = 'theme_mode';

/// Riverpod provider — provides the current [ThemeMode] and allows toggling.
final themeServiceProvider = AsyncNotifierProvider<ThemeService, ThemeMode>(
  ThemeService.new,
);

class ThemeService extends AsyncNotifier<ThemeMode> {
  static const _light = 'light';
  static const _dark = 'dark';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    return _fromString(stored);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Switch to light (Japanese parchment) theme.
  Future<void> setLight() => _persist(ThemeMode.light);

  /// Switch to dark theme.
  Future<void> setDark() => _persist(ThemeMode.dark);

  /// Toggle between light and dark.
  Future<void> toggle() async {
    final current = state.value ?? ThemeMode.light;
    await _persist(
      current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  /// Returns true if current mode is dark.
  bool get isDark => state.value == ThemeMode.dark;

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _persist(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _toString(mode));
  }

  static ThemeMode _fromString(String? s) {
    switch (s) {
      case _dark:
        return ThemeMode.dark;
      case _light:
      default:
        return ThemeMode.light;
    }
  }

  static String _toString(ThemeMode mode) =>
      mode == ThemeMode.dark ? _dark : _light;
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience extension — use in any widget to check current brightness.
// ─────────────────────────────────────────────────────────────────────────────
extension ThemeServiceX on WidgetRef {
  ThemeMode get themeMode =>
      watch(themeServiceProvider).value ?? ThemeMode.light;

  bool get isDarkMode => themeMode == ThemeMode.dark;
}
