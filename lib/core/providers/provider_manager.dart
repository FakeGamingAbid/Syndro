import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/remote_config_service.dart';
import 'cs3_auto_updater.dart';
import 'cs3_loader.dart';
import 'repo_fetcher.dart';

/// Provider state enum
enum ProviderState {
  uninitialized,
  loading,
  ready,
  error,
}

/// Provider status for a single provider
class ProviderStatus {
  final String internalName;
  final String name;
  final int version;
  final bool isEnabled;
  final bool isLoaded;
  final bool hasUpdate;
  final String? error;

  ProviderStatus({
    required this.internalName,
    required this.name,
    required this.version,
    required this.isEnabled,
    required this.isLoaded,
    this.hasUpdate = false,
    this.error,
  });

  ProviderStatus copyWith({
    String? internalName,
    String? name,
    int? version,
    bool? isEnabled,
    bool? isLoaded,
    bool? hasUpdate,
    String? error,
  }) {
    return ProviderStatus(
      internalName: internalName ?? this.internalName,
      name: name ?? this.name,
      version: version ?? this.version,
      isEnabled: isEnabled ?? this.isEnabled,
      isLoaded: isLoaded ?? this.isLoaded,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      error: error,
    );
  }
}

/// Provider manager state
class ProviderManagerState {
  final ProviderState state;
  final List<ProviderStatus> providers;
  final String? error;
  final DateTime? lastUpdate;

  ProviderManagerState({
    this.state = ProviderState.uninitialized,
    this.providers = const [],
    this.error,
    this.lastUpdate,
  });

  ProviderManagerState copyWith({
    ProviderState? state,
    List<ProviderStatus>? providers,
    String? error,
    DateTime? lastUpdate,
  }) {
    return ProviderManagerState(
      state: state ?? this.state,
      providers: providers ?? this.providers,
      error: error,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Provider for ProviderManager
final providerManagerProvider =
    StateNotifierProvider<ProviderManager, ProviderManagerState>((ref) {
  return ProviderManager(ref);
});

/// Provider Manager - orchestrates all provider services
class ProviderManager extends StateNotifier<ProviderManagerState> {
  final Ref _ref;
  
  // 24 hour update interval
  static const _updateInterval = Duration(hours: 24);

  ProviderManager(this._ref) : super(ProviderManagerState());

  RemoteConfigService get _config => _ref.read(remoteConfigServiceProvider);
  RepoFetcher get _repoFetcher => _ref.read(repoFetcherProvider);
  CS3AutoUpdater get _autoUpdater => _ref.read(cs3AutoUpdaterProvider);
  CS3Loader get _loader => _ref.read(cs3LoaderProvider);

  /// Initialize the provider system
  /// Fetches config, repos, updates providers, loads enabled ones
  Future<void> initialize() async {
    if (state.state == ProviderState.loading) return;

    state = state.copyWith(state: ProviderState.loading);

    try {
      // Load cached config first
      await _config.loadCachedConfig();

      // Fetch fresh config
      await _config.fetchConfig();

      // Get repos from config
      final repos = _config.cloudstreamRepos;
      final repoUrls = repos.map((r) => r.url).toList();

      // Fetch plugins from all repos
      final plugins = await _repoFetcher.fetchAllRepos(repoUrls);

      // Check for updates and download new providers
      await _autoUpdater.checkAndUpdate(plugins);

      // Get installed providers
      final installed = await _autoUpdater.getInstalledProviders();

      // Build provider list
      final providerStatuses = <ProviderStatus>[];
      
      for (final plugin in plugins) {
        final isInstalled = installed.contains(plugin.internalName);
        final currentVersion = await _autoUpdater.getLocalVersion(plugin.internalName);
        final hasUpdate = currentVersion < plugin.version;

        providerStatuses.add(ProviderStatus(
          internalName: plugin.internalName,
          name: plugin.name,
          version: isInstalled ? currentVersion : plugin.version,
          isEnabled: true, // All downloaded are enabled by default
          isLoaded: false,
          hasUpdate: hasUpdate,
        ));
      }

      // Sort by name
      providerStatuses.sort((a, b) => a.name.compareTo(b.name));

      state = state.copyWith(
        state: ProviderState.ready,
        providers: providerStatuses,
        lastUpdate: DateTime.now(),
      );

      // Auto-load enabled providers
      await _loadEnabledProviders();

      debugPrint('Provider system initialized with ${providerStatuses.length} providers');
    } catch (e) {
      debugPrint('Error initializing provider system: $e');
      state = state.copyWith(
        state: ProviderState.error,
        error: e.toString(),
      );
    }
  }

  /// Check for updates manually
  Future<void> checkForUpdates() async {
    try {
      // Get repos from config
      final repos = _config.cloudstreamRepos;
      final repoUrls = repos.map((r) => r.url).toList();

      // Fetch latest plugins
      final plugins = await _repoFetcher.fetchAllRepos(repoUrls);

      // Check for updates
      final results = await _autoUpdater.checkAndUpdate(plugins);

      // Update provider states
      final updatedProviders = state.providers.map((p) {
        final result = results.firstWhere(
          (r) => r.internalName == p.internalName,
          orElse: () => UpdateCheckResult(
            internalName: p.internalName,
            hasUpdate: false,
            currentVersion: p.version,
            newVersion: p.version,
          ),
        );
        
        return p.copyWith(
          version: result.newVersion,
          hasUpdate: result.hasUpdate,
        );
      }).toList();

      state = state.copyWith(
        providers: updatedProviders,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  /// Load all enabled providers
  Future<void> _loadEnabledProviders() async {
    final enabledProviders = state.providers.where((p) => p.isEnabled);
    
    for (final provider in enabledProviders) {
      await _loader.loadProvider(provider.internalName);
    }

    // Update loaded states
    final loadedNames = _loader.loadedProviders;
    final updatedProviders = state.providers.map((p) {
      return p.copyWith(isLoaded: loadedNames.contains(p.internalName));
    }).toList();

    state = state.copyWith(providers: updatedProviders);
  }

  /// Toggle provider enabled state
  Future<void> toggleProvider(String internalName, bool enabled) async {
    final updatedProviders = state.providers.map((p) {
      if (p.internalName == internalName) {
        return p.copyWith(isEnabled: enabled);
      }
      return p;
    }).toList();

    state = state.copyWith(providers: updatedProviders);

    // Load or unload based on enabled state
    if (enabled) {
      await _loader.loadProvider(internalName);
    } else {
      await _loader.unloadProvider(internalName);
    }

    // Update loaded states
    final loadedNames = _loader.loadedProviders;
    final finalProviders = state.providers.map((p) {
      return p.copyWith(isLoaded: loadedNames.contains(p.internalName));
    }).toList();

    state = state.copyWith(providers: finalProviders);
  }

  /// Search across all enabled providers
  /// Returns results from all providers in parallel
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? type,
    int page = 1,
  }) async {
    if (query.isEmpty) return [];

    final results = await _loader.search(query, type: type, page: page);
    return results;
  }

  /// Get details from a specific provider
  Future<Map<String, dynamic>?> getDetails(
    String providerInternalName,
    String id,
  ) async {
    return await _loader.getDetails(providerInternalName, id);
  }

  /// Get stream links from a specific provider
  Future<List<Map<String, dynamic>>> getLinks(
    String providerInternalName,
    String id, {
    String? episode,
    String? season,
  }) async {
    return await _loader.getLinks(
      providerInternalName,
      id,
      episode: episode,
      season: season,
    );
  }

  /// Get all links from all enabled providers in parallel
  Future<List<Map<String, dynamic>>> getAllLinks(
    String id, {
    String? episode,
    String? season,
  }) async {
    final allLinks = <Map<String, dynamic>>[];
    final enabledProviders = state.providers.where((p) => p.isEnabled);

    // Query all providers in parallel
    final futures = enabledProviders.map((p) =>
      _loader.getLinks(p.internalName, id, episode: episode, season: season)
    );

    final results = await Future.wait(futures);
    
    for (final links in results) {
      allLinks.addAll(links);
    }

    // Sort by quality (prefer higher quality)
    allLinks.sort((a, b) {
      final qualityA = _parseQuality(a['quality']?.toString() ?? '');
      final qualityB = _parseQuality(b['quality']?.toString() ?? '');
      return qualityB.compareTo(qualityA);
    });

    return allLinks;
  }

  int _parseQuality(String quality) {
    if (quality.contains('4k')) return 2160;
    if (quality.contains('1080')) return 1080;
    if (quality.contains('720')) return 720;
    if (quality.contains('480')) return 480;
    if (quality.contains('360')) return 360;
    if (quality.contains('240')) return 240;
    return 0;
  }

  /// Get a provider by internal name
  ProviderStatus? getProvider(String internalName) {
    try {
      return state.providers.firstWhere((p) => p.internalName == internalName);
    } catch (e) {
      return null;
    }
  }

  /// Delete a provider
  Future<void> deleteProvider(String internalName) async {
    await _autoUpdater.deleteProvider(internalName);
    await _loader.unloadProvider(internalName);

    final updatedProviders = state.providers
        .where((p) => p.internalName != internalName)
        .toList();

    state = state.copyWith(providers: updatedProviders);
  }

  /// Dispose
  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }
}
