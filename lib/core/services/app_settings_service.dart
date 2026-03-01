import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _autoAcceptTrustedKey = 'auto_accept_trusted_devices';
  static const String _autoDeleteHistoryDaysKey = 'auto_delete_history_days';
  static const String _localeKey = 'app_locale';

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

  /// Get auto-delete history days (0 = disabled)
  Future<int> getAutoDeleteHistoryDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_autoDeleteHistoryDaysKey) ?? 30; // Default: 30 days
    } catch (e) {
      return 30;
    }
  }

  /// Set auto-delete history days (0 = disabled)
  Future<void> setAutoDeleteHistoryDays(int days) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_autoDeleteHistoryDaysKey, days);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get app locale code (null = system default)
  Future<String?> getLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_localeKey);
    } catch (e) {
      return null;
    }
  }

  /// Set app locale code (null = system default)
  Future<void> setLocale(String? localeCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (localeCode == null) {
        await prefs.remove(_localeKey);
      } else {
        await prefs.setString(_localeKey, localeCode);
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
