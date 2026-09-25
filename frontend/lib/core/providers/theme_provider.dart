import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'app_theme_mode';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restoreSavedThemeMode();
    return ThemeMode.light;
  }

  Future<void> _restoreSavedThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themeModeKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      }
    } catch (_) {
      // If preferences aren't available, keep default light theme
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;

  Future<void> toggleTheme() async {
    await setDarkMode(state != ThemeMode.dark);
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, enabled ? 'dark' : 'light');
    } catch (_) {
      // Non-fatal: the toggle still works for this session
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(() {
  return ThemeModeController();
});