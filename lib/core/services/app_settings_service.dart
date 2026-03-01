import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _autoAcceptTrustedKey = 'auto_accept_trusted_devices';

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
}
