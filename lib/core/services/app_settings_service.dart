import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _autoAcceptTrustedKey = 'auto_accept_trusted_devices';
  static const String _themeModeKey = 'app_theme_mode';

  /// Get whether to auto-accept transfers from trusted devices
  Future<bool> getAutoAcceptTrusted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoAcceptTrustedKey) ?? false; // Default: false (always ask)
    } catch (e) {
      return false;
    }
  }

  /// Set whether to auto-accept transfers from trusted devices
  Future<void> setAutoAcceptTrusted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoAcceptTrustedKey, value);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get the current theme mode
  Future<ThemeMode> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeModeKey);
      if (value == 'light') return ThemeMode.light;
      if (value == 'system') return ThemeMode.system;
      return ThemeMode.dark;
    } catch (e) {
      return ThemeMode.dark;
    }
  }

  /// Set the theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.system
              ? 'system'
              : 'dark';
      await prefs.setString(_themeModeKey, value);
    } catch (e) {
      // Ignore errors
    }
  }
}
