import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    state = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    return ThemeModeController();
  },
);

// Accent seed options — a small curated palette.
const accentSeeds = <Color>[
  Color(0xFF3B82F6), // blue (default)
  Color(0xFF06B6D4), // cyan
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEC4899), // pink
  Color(0xFF8B5CF6), // violet
];

/// The violet that used to be the default. Installs still carrying it as a
/// stored preference are moved to the new blue default once; anything else the
/// user picked deliberately is left alone.
const _legacyDefaultSeed = Color(0xFF6C5CE7);

class AccentSeedController extends StateNotifier<Color> {
  AccentSeedController() : super(accentSeeds[0]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('accent_seed');
    if (value == null) return;
    final stored = Color(value & 0xFFFFFFFF);
    if (stored == _legacyDefaultSeed &&
        !(prefs.getBool('accent_seed_migrated') ?? false)) {
      await prefs.setBool('accent_seed_migrated', true);
      await setSeed(accentSeeds[0]);
      return;
    }
    state = stored;
  }

  Future<void> setSeed(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_seed', color.toARGB32());
  }
}

final accentSeedProvider = StateNotifierProvider<AccentSeedController, Color>((
  ref,
) {
  return AccentSeedController();
});
