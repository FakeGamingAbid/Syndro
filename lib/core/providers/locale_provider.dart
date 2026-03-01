import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_settings_service.dart';

/// Available locales in the app
class AppLocale {
  final String code;
  final String name;
  final Locale locale;

  const AppLocale({
    required this.code,
    required this.name,
    required this.locale,
  });
}

/// List of supported locales
const List<AppLocale> supportedLocales = [
  AppLocale(code: 'en', name: 'English', locale: Locale('en')),
  AppLocale(code: 'es', name: 'Español', locale: Locale('es')),
  AppLocale(code: 'fr', name: 'Français', locale: Locale('fr')),
  AppLocale(code: 'de', name: 'Deutsch', locale: Locale('de')),
  AppLocale(code: 'zh', name: '中文', locale: Locale('zh')),
  AppLocale(code: 'ja', name: '日本語', locale: Locale('ja')),
];

/// Provider for the current app locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Notifier to manage app locale
class LocaleNotifier extends StateNotifier<Locale?> {
  final AppSettingsService _settingsService = AppSettingsService();

  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final localeCode = await _settingsService.getLocale();
    if (localeCode != null) {
      state = Locale(localeCode);
    }
  }

  Future<void> setLocale(AppLocale? appLocale) async {
    if (appLocale == null) {
      // System default
      await _settingsService.setLocale(null);
      state = null;
    } else {
      await _settingsService.setLocale(appLocale.code);
      state = appLocale.locale;
    }
  }

  AppLocale? get currentAppLocale {
    if (state == null) return null;
    return supportedLocales.firstWhere(
      (l) => l.code == state!.languageCode,
      orElse: () => supportedLocales.first,
    );
  }
}
