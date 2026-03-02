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
  AppLocale(code: 'zh', name: '中文', locale: Locale('zh')),
  AppLocale(code: 'ja', name: '日本語', locale: Locale('ja')),
];

/// Get system locale and map to supported locale
Locale? _getSystemLocale() {
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final languageCode = systemLocale.languageCode;
  
  // Check if system language is supported
  final supportedCodes = ['en', 'es', 'zh', 'ja'];
  if (supportedCodes.contains(languageCode)) {
    return Locale(languageCode);
  }
  
  // Default to English if not supported
  return const Locale('en');
}

/// Simple locale state
class LocaleState {
  final Locale? locale;
  final bool isLoading;

  const LocaleState({this.locale, this.isLoading = true});

  LocaleState copyWith({Locale? locale, bool? isLoading}) {
    return LocaleState(
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider for locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, LocaleState>((ref) {
  return LocaleNotifier();
});

/// Notifier to manage app locale
class LocaleNotifier extends StateNotifier<LocaleState> {
  final AppSettingsService _settingsService = AppSettingsService();

  LocaleNotifier() : super(const LocaleState()) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final localeCode = await _settingsService.getLocale();
      if (localeCode != null) {
        // User has selected a locale - use it
        state = LocaleState(locale: Locale(localeCode), isLoading: false);
      } else {
        // No saved locale - detect system language
        final systemLocale = _getSystemLocale();
        state = LocaleState(locale: systemLocale, isLoading: false);
      }
    } catch (e) {
      // On error, use system locale as fallback
      state = LocaleState(locale: _getSystemLocale(), isLoading: false);
    }
  }

  Future<void> setLocale(AppLocale? appLocale) async {
    if (appLocale == null) {
      await _settingsService.setLocale(null);
      state = state.copyWith(locale: null);
    } else {
      await _settingsService.setLocale(appLocale.code);
      state = state.copyWith(locale: appLocale.locale);
    }
  }

  AppLocale? get currentAppLocale {
    if (state.locale == null) {
      // Return system locale's corresponding AppLocale
      final systemLocale = _getSystemLocale();
      if (systemLocale == null) {
        return supportedLocales.first;
      }
      return supportedLocales.firstWhere(
        (l) => l.code == systemLocale.languageCode,
        orElse: () => supportedLocales.first,
      );
    }
    return supportedLocales.firstWhere(
      (l) => l.code == state.locale!.languageCode,
      orElse: () => supportedLocales.first,
    );
  }
  
  /// Get the effective locale (user selected or system)
  Locale get effectiveLocale => state.locale ?? _getSystemLocale() ?? const Locale('en');
}
