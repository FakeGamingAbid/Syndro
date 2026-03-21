import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../providers/providers.dart';

/// URL for fetching remote config - injected at build time via dart-define
const String configUrl = String.fromEnvironment(
  'CONFIG_URL',
  defaultValue: 'https://moonplex.github.io/config/config.json',
);

/// Provider for RemoteConfigService
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService(ref);
});

/// Update status enum
enum UpdateStatus {
  none,
  soft,
  required,
}

/// Remote configuration service
/// Fetches config.json from GitHub Pages on every launch
class RemoteConfigService {
  final Ref _ref;
  late final Dio _dio;
  AppConfig? _cachedConfig;

  RemoteConfigService(this._ref) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Static method to get config (for use without Ref)
  /// Returns empty map if not available
  static Future<Map<String, dynamic>> getConfig() async {
    return {};
  }

  /// Fetch config from remote URL
  Future<AppConfig> fetchConfig() async {
    try {
      final response = await _dio.get(configUrl);
      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        final config = AppConfig.fromJson(json);

        // Cache to database
        await _cacheConfig(config);

        _cachedConfig = config;
        return config;
      }
      throw Exception('Failed to fetch config: ${response.statusCode}');
    } on DioException catch (e) {
      // Network error - try to load cached config
      debugPrint('Network error fetching config: ${e.message}');
      return loadCachedConfig();
    }
  }

  /// Load cached config from Drift database
  Future<AppConfig> loadCachedConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    final db = _ref.read(appDatabaseProvider);
    final cached = await db.getCachedConfig();

    if (cached != null) {
      try {
        final json = jsonDecode(cached.jsonData) as Map<String, dynamic>;
        _cachedConfig = AppConfig.fromJson(json);
        return _cachedConfig!;
      } catch (e) {
        debugPrint('Error parsing cached config: $e');
      }
    }

    // Return default config if nothing cached
    return AppConfig.defaultConfig();
  }

  /// Cache config to database
  Future<void> _cacheConfig(AppConfig config) async {
    final db = _ref.read(appDatabaseProvider);
    await db.setCachedConfig(jsonEncode(config.toJson()));
  }

  /// Check if app update is required
  UpdateStatus checkForUpdate(String currentVersion) {
    final config = _cachedConfig;
    if (config == null) return UpdateStatus.none;

    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(config.latestAppVersion);
    final minimum = _parseVersion(config.minAppVersion);

    if (_compareVersions(current, minimum) < 0) {
      return UpdateStatus.required;
    }
    if (_compareVersions(current, latest) < 0) {
      return UpdateStatus.soft;
    }
    return UpdateStatus.none;
  }

  List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  int _compareVersions(List<int> a, List<int> b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < maxLen; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }

  /// Get TMDB API key
  String? get tmdbApiKey => _cachedConfig?.tmdbApiKey;

  /// Get OpenSubtitles API key
  String? get opensubtitlesApiKey => _cachedConfig?.opensubtitlesApiKey;

  /// Get cloudstream repos
  List<RepoConfig> get cloudstreamRepos =>
      _cachedConfig?.cloudstreamRepos ?? [];

  /// Get default providers
  List<ProviderConfig> get defaultProviders =>
      _cachedConfig?.defaultProviders ?? [];
}

/// App configuration model
class AppConfig {
  final String tmdbApiKey;
  final String opensubtitlesApiKey;
  final List<RepoConfig> cloudstreamRepos;
  final List<ProviderConfig> defaultProviders;
  final String latestAppVersion;
  final String minAppVersion;
  final String updateUrl;
  final bool updateRequired;
  final String updateMessage;

  AppConfig({
    required this.tmdbApiKey,
    required this.opensubtitlesApiKey,
    required this.cloudstreamRepos,
    required this.defaultProviders,
    required this.latestAppVersion,
    required this.minAppVersion,
    required this.updateUrl,
    required this.updateRequired,
    required this.updateMessage,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      tmdbApiKey: json['tmdb_api_key'] as String? ?? '',
      opensubtitlesApiKey: json['opensubtitles_api_key'] as String? ?? '',
      cloudstreamRepos: (json['cloudstream_repos'] as List<dynamic>?)
              ?.map((e) => RepoConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      defaultProviders: (json['default_providers'] as List<dynamic>?)
              ?.map((e) => ProviderConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      latestAppVersion: json['latest_app_version'] as String? ?? '1.0.0',
      minAppVersion: json['min_app_version'] as String? ?? '1.0.0',
      updateUrl: json['update_url'] as String? ?? '',
      updateRequired: json['update_required'] as bool? ?? false,
      updateMessage: json['update_message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tmdb_api_key': tmdbApiKey,
      'opensubtitles_api_key': opensubtitlesApiKey,
      'cloudstream_repos': cloudstreamRepos.map((e) => e.toJson()).toList(),
      'default_providers': defaultProviders.map((e) => e.toJson()).toList(),
      'latest_app_version': latestAppVersion,
      'min_app_version': minAppVersion,
      'update_url': updateUrl,
      'update_required': updateRequired,
      'update_message': updateMessage,
    };
  }

  factory AppConfig.defaultConfig() {
    return AppConfig(
      tmdbApiKey: '',
      opensubtitlesApiKey: '',
      cloudstreamRepos: [],
      defaultProviders: [],
      latestAppVersion: '1.0.0',
      minAppVersion: '1.0.0',
      updateUrl: '',
      updateRequired: false,
      updateMessage: '',
    );
  }
}

/// Repository configuration
class RepoConfig {
  final String name;
  final String url;

  RepoConfig({required this.name, required this.url});

  factory RepoConfig.fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }
}

/// Provider configuration
class ProviderConfig {
  final String internalName;
  final String url;
  final int version;
  final bool enabled;
  final int priority;

  ProviderConfig({
    required this.internalName,
    required this.url,
    required this.version,
    required this.enabled,
    required this.priority,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      internalName: json['internalName'] as String,
      url: json['url'] as String,
      version: json['version'] as int,
      enabled: json['enabled'] as bool? ?? true,
      priority: json['priority'] as int? ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'internalName': internalName,
      'url': url,
      'version': version,
      'enabled': enabled,
      'priority': priority,
    };
  }
}
