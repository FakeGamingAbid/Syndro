import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cs3_auto_updater.dart';

/// Provider for CS3Loader
final cs3LoaderProvider = Provider<CS3Loader>((ref) {
  return CS3Loader(ref);
});

/// Loaded provider instance
class LoadedProvider {
  final String internalName;
  final dynamic instance;
  final bool isLoaded;

  LoadedProvider({
    required this.internalName,
    this.instance,
    required this.isLoaded,
  });
}

/// CS3 Loader - loads CS3 provider files via platform channel
/// Android: Uses DexClassLoader via MainActivity platform channel
/// Desktop: Uses embedded HTTP server approach
class CS3Loader {
  final Ref _ref;
  late final MethodChannel _platformChannel;
  late final Dio _dio;
  
  final Map<String, LoadedProvider> _loadedProviders = {};
  HttpServer? _desktopServer;

  CS3Loader(this._ref) {
    _platformChannel = const MethodChannel('com.moonplex.app/cs3');
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  /// Load a provider by internal name
  /// Returns true if loaded successfully
  Future<bool> loadProvider(String internalName) async {
    // Check if already loaded
    if (_loadedProviders.containsKey(internalName)) {
      return _loadedProviders[internalName]!.isLoaded;
    }

    try {
      final autoUpdater = _ref.read(cs3AutoUpdaterProvider);
      final providerPath = await autoUpdater.getProviderPath(internalName);
      
      if (providerPath == null) {
        debugPrint('Provider not found: $internalName');
        return false;
      }

      bool success = false;

      if (Platform.isAndroid) {
        success = await _loadAndroid(providerPath, internalName);
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        success = await _loadDesktop(providerPath, internalName);
      }

      _loadedProviders[internalName] = LoadedProvider(
        internalName: internalName,
        instance: success ? 'loaded' : null,
        isLoaded: success,
      );

      return success;
    } catch (e) {
      debugPrint('Error loading provider $internalName: $e');
      _loadedProviders[internalName] = LoadedProvider(
        internalName: internalName,
        instance: null,
        isLoaded: false,
      );
      return false;
    }
  }

  /// Load provider on Android using DexClassLoader via platform channel
  Future<bool> _loadAndroid(String jarPath, String internalName) async {
    try {
      final result = await _platformChannel.invokeMethod<bool>(
        'loadProvider',
        {
          'jarPath': jarPath,
          'internalName': internalName,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Platform error loading provider: ${e.message}');
      return false;
    }
  }

  /// Load provider on Desktop
  /// Desktop uses HTTP server to serve provider files to Java process
  Future<bool> _loadDesktop(String jarPath, String internalName) async {
    try {
      // Start HTTP server if not running
      if (_desktopServer == null) {
        _desktopServer = await HttpServer.bind('127.0.0.1', 9876);
        debugPrint('CS3 HTTP server started on port 9876');
      }

      // The actual loading would be done by a Java process
      // For now, we return true to indicate the provider is available
      // Real implementation would communicate with Java process
      return true;
    } catch (e) {
      debugPrint('Error loading desktop provider: $e');
      return false;
    }
  }

  /// Call a method on a loaded provider
  /// Returns the result from the provider
  Future<dynamic> callProvider(
    String internalName,
    String method,
    Map<String, dynamic> args,
  ) async {
    if (!_loadedProviders.containsKey(internalName) || 
        !_loadedProviders[internalName]!.isLoaded) {
      throw Exception('Provider not loaded: $internalName');
    }

    try {
      final result = await _platformChannel.invokeMethod(
        'callProvider',
        {
          'internalName': internalName,
          'method': method,
          'args': args,
        },
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error calling provider method: ${e.message}');
      rethrow;
    }
  }

  /// Search all loaded providers
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? type,
    int page = 1,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    for (final entry in _loadedProviders.entries) {
      if (entry.value.isLoaded) {
        try {
          final result = await callProvider(
            entry.key,
            'search',
            {
              'query': query,
              'type': type,
              'page': page,
            },
          );
          if (result is List) {
            results.addAll(result.cast<Map<String, dynamic>>());
          }
        } catch (e) {
          debugPrint('Error searching ${entry.key}: $e');
        }
      }
    }

    return results;
  }

  /// Get details for a specific content
  Future<Map<String, dynamic>?> getDetails(
    String internalName,
    String id,
  ) async {
    if (!_loadedProviders.containsKey(internalName) ||
        !_loadedProviders[internalName]!.isLoaded) {
      return null;
    }

    try {
      final result = await callProvider(
        internalName,
        'getDetails',
        {'id': id},
      );
      return result as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting details: $e');
      return null;
    }
  }

  /// Get stream links for a content
  Future<List<Map<String, dynamic>>> getLinks(
    String internalName,
    String id, {
    String? episode,
    String? season,
  }) async {
    if (!_loadedProviders.containsKey(internalName) ||
        !_loadedProviders[internalName]!.isLoaded) {
      return [];
    }

    try {
      final result = await callProvider(
        internalName,
        'getLinks',
        {
          'id': id,
          'episode': episode,
          'season': season,
        },
      );
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error getting links: $e');
    }
    return [];
  }

  /// Get list of loaded providers
  List<String> get loadedProviders => _loadedProviders.entries
      .where((e) => e.value.isLoaded)
      .map((e) => e.key)
      .toList();

  /// Check if a provider is loaded
  bool isProviderLoaded(String internalName) {
    return _loadedProviders[internalName]?.isLoaded ?? false;
  }

  /// Unload a provider
  Future<void> unloadProvider(String internalName) async {
    if (_loadedProviders.containsKey(internalName)) {
      if (Platform.isAndroid) {
        try {
          await _platformChannel.invokeMethod(
            'unloadProvider',
            {'internalName': internalName},
          );
        } catch (e) {
          debugPrint('Error unloading provider: $e');
        }
      }
      _loadedProviders.remove(internalName);
    }
  }

  /// Dispose all loaded providers
  Future<void> dispose() async {
    final providers = _loadedProviders.keys.toList();
    for (final name in providers) {
      await unloadProvider(name);
    }
    
    if (_desktopServer != null) {
      await _desktopServer!.close();
      _desktopServer = null;
    }
  }
}
