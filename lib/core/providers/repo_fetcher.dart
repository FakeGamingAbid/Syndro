
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for RepoFetcher
final repoFetcherProvider = Provider<RepoFetcher>((ref) {
  return RepoFetcher();
});

/// Repo fetcher service
/// Fetches plugins.json from configured CloudStream repos
class RepoFetcher {
  late final Dio _dio;

  RepoFetcher() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  /// Fetch plugins from all configured repos
  /// Merges and deduplicates plugins by internalName
  Future<List<PluginInfo>> fetchAllRepos(
    List<String> repoUrls,
  ) async {
    final List<PluginInfo> allPlugins = [];
    final seen = <String>{};

    for (final repoUrl in repoUrls) {
      try {
        final plugins = await _fetchRepoPlugins(repoUrl);
        for (final plugin in plugins) {
          if (!seen.contains(plugin.internalName)) {
            seen.add(plugin.internalName);
            allPlugins.add(plugin);
          }
        }
      } catch (e) {
        debugPrint('Error fetching repo $repoUrl: $e');
      }
    }

    // Sort by name
    allPlugins.sort((a, b) => a.name.compareTo(b.name));
    return allPlugins;
  }

  /// Fetch plugins from a single repo
  Future<List<PluginInfo>> _fetchRepoPlugins(String repoUrl) async {
    // Normalize URL
    final baseUrl = repoUrl.endsWith('/') 
        ? repoUrl.substring(0, repoUrl.length - 1) 
        : repoUrl;
    
    final pluginsUrl = '$baseUrl/plugins.json';

    final response = await _dio.get(pluginsUrl);
    if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Single plugin format
        return [PluginInfo.fromJson(data, baseUrl)];
      } else if (data is List) {
        // Array of plugins format
        return data
            .map((e) => PluginInfo.fromJson(e as Map<String, dynamic>, baseUrl))
            .toList();
      }
    }
    return [];
  }

  /// Fetch repo metadata (description, version)
  Future<RepoMetadata?> fetchRepoMetadata(String repoUrl) async {
    try {
      final baseUrl = repoUrl.endsWith('/') 
          ? repoUrl.substring(0, repoUrl.length - 1) 
          : repoUrl;
      
      final metaUrl = '$baseUrl/meta.json';
      final response = await _dio.get(metaUrl);
      
      if (response.statusCode == 200) {
        return RepoMetadata.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error fetching repo metadata: $e');
    }
    return null;
  }
}

/// Plugin information from CS3 providers
class PluginInfo {
  final String name;
  final String internalName;
  final String description;
  final String url;
  final int version;
  final String? iconUrl;
  final String? author;
  final List<String> languages;
  final List<String> tvTypes;
  final String? repoUrl;

  PluginInfo({
    required this.name,
    required this.internalName,
    required this.description,
    required this.url,
    required this.version,
    this.iconUrl,
    this.author,
    required this.languages,
    required this.tvTypes,
    this.repoUrl,
  });

  factory PluginInfo.fromJson(Map<String, dynamic> json, String baseUrl) {
    return PluginInfo(
      name: json['name'] as String? ?? 'Unknown',
      internalName: json['internalName'] as String? ?? 
          json['name']?.toString().toLowerCase().replaceAll(' ', '') ?? 
          'unknown',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? 
          '$baseUrl/${json['file'] ?? 'plugin.jar'}',
      version: json['version'] as int? ?? 1,
      iconUrl: json['iconUrl'] as String?,
      author: json['author'] as String?,
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['en'],
      tvTypes: (json['tvTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      repoUrl: baseUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'internalName': internalName,
      'description': description,
      'url': url,
      'version': version,
      'iconUrl': iconUrl,
      'author': author,
      'languages': languages,
      'tvTypes': tvTypes,
    };
  }
}

/// Repository metadata
class RepoMetadata {
  final String name;
  final String description;
  final String version;
  final String? iconUrl;
  final List<String> authors;

  RepoMetadata({
    required this.name,
    required this.description,
    required this.version,
    this.iconUrl,
    required this.authors,
  });

  factory RepoMetadata.fromJson(Map<String, dynamic> json) {
    return RepoMetadata(
      name: json['name'] as String? ?? 'Unknown Repo',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      iconUrl: json['iconUrl'] as String?,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
