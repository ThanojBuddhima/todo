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

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

// Accent seed options — a small curated palette.
const accentSeeds = <Color>[
  Color(0xFF6C5CE7), // indigo-violet (default)
  Color(0xFF0EA5E9), // sky blue
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFFEC4899), // pink
];

class AccentSeedController extends StateNotifier<Color> {
  AccentSeedController() : super(accentSeeds[0]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('accent_seed');
    if (value != null) state = Color(value & 0xFFFFFFFF);
  }

  Future<void> setSeed(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_seed', color.toARGB32());
  }
}

final accentSeedProvider = StateNotifierProvider<AccentSeedController, Color>((ref) {
  return AccentSeedController();
});
