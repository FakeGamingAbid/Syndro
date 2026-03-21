import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../config/remote_config_service.dart';

/// Provider for OpenSubtitlesService
final opensubtitlesServiceProvider = Provider<OpenSubtitlesService>((ref) {
  return OpenSubtitlesService(ref);
});

/// Subtitle result from OpenSubtitles API
class SubtitleResult {
  final String fileId;
  final String language;
  final String languageCode;
  final String fileName;
  final int downloadCount;
  final DateTime? uploadedAt;

  SubtitleResult({
    required this.fileId,
    required this.language,
    required this.languageCode,
    required this.fileName,
    required this.downloadCount,
    this.uploadedAt,
  });

  factory SubtitleResult.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final langData = attrs['language'] as String? ?? 'en';

    return SubtitleResult(
      fileId: json['id']?.toString() ?? '',
      language: _languageName(langData),
      languageCode: langData,
      fileName: attrs['file_name'] as String? ?? 'unknown.srt',
      downloadCount: attrs['download_count'] as int? ?? 0,
      uploadedAt: attrs['upload_date'] != null
          ? DateTime.tryParse(attrs['upload_date'] as String)
          : null,
    );
  }

  /// Convert language code to full name
  static String _languageName(String code) {
    const names = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'hi': 'Hindi',
    };
    return names[code] ?? code;
  }
}

/// OpenSubtitles API service
class OpenSubtitlesService {
  final Ref _ref;
  late final Dio _dio;

  static const String _baseUrl = 'https://api.opensubtitles.com/api/v1';
  String? _apiKey;

  OpenSubtitlesService(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Get API key from remote config
    _initApiKey();
  }

  void _initApiKey() {
    try {
      final configService = _ref.read(remoteConfigServiceProvider);
      _apiKey = configService.opensubtitlesApiKey;
    } catch (e) {
      debugPrint('Error getting OpenSubtitles API key: $e');
    }
  }

  Map<String, String> get _headers => {
        'Api-Key': _apiKey ?? '',
        'Content-Type': 'application/json',
      };

  /// Search for subtitles by IMDB ID
  Future<List<SubtitleResult>> search(String imdbId, String language) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('OpenSubtitles API key not configured');
      return [];
    }

    try {
      final response = await _dio.get(
        '/subtitles',
        queryParameters: {
          'imdb_id': imdbId,
          'languages': language,
        },
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final dataList = data['data'] as List<dynamic>? ?? [];

        final results = dataList
            .map((e) => SubtitleResult.fromJson(e as Map<String, dynamic>))
            .toList();

        // Sort by download count (most popular first)
        results.sort((a, b) => b.downloadCount.compareTo(a.downloadCount));

        return results;
      }
    } on DioException catch (e) {
      debugPrint('OpenSubtitles search error: ${e.message}');
    }
    return [];
  }

  /// Get download URL for a subtitle file
  Future<String?> getDownloadUrl(String fileId) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.post(
        '/download',
        data: {'file_id': fileId},
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['link'] as String?;
      }
    } on DioException catch (e) {
      debugPrint('OpenSubtitles download URL error: ${e.message}');
    }
    return null;
  }

  /// Download subtitle file to cache
  Future<String> downloadToCache(String url, String filename) async {
    final cacheDir = await _getSubtitleCacheDir();
    final path = '${cacheDir.path}/$filename';

    await _dio.download(url, path);
    return path;
  }

  /// Get platform-specific subtitle cache directory
  Future<Directory> _getSubtitleCacheDir() async {
    Directory cacheDir;

    if (Platform.isAndroid) {
      cacheDir = Directory('/data/data/com.moonplex.app/cache/subtitles');
    } else if (Platform.isWindows) {
      final tempDir = await getTemporaryDirectory();
      cacheDir = Directory('${tempDir.path}/moonplex/subtitles');
    } else if (Platform.isLinux) {
      cacheDir = Directory('/tmp/moonplex/subtitles');
    } else if (Platform.isMacOS) {
      final cachePath =
          '${Platform.environment['HOME']}/Library/Caches/Moonplex/subtitles';
      cacheDir = Directory(cachePath);
    } else {
      cacheDir = await getTemporaryDirectory();
    }

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Get language name from code
  static String _languageName(String code) {
    const names = {
      'en': 'English',
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ml': 'Malayalam',
      'kn': 'Kannada',
      'mr': 'Marathi',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'tr': 'Turkish',
      'pl': 'Polish',
      'nl': 'Dutch',
      'sv': 'Swedish',
      'da': 'Danish',
      'fi': 'Finnish',
      'no': 'Norwegian',
    };
    return names[code.toLowerCase()] ?? code.toUpperCase();
  }

  /// Get available languages list
  Future<List<String>> getAvailableLanguages() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return ['en'];
    }

    try {
      final response = await _dio.get(
        '/languages',
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final dataList = data['data'] as List<dynamic>? ?? [];

        return dataList
            .map((e) => (e as Map<String, dynamic>)['language_code'] as String)
            .toList();
      }
    } on DioException catch (e) {
      debugPrint('OpenSubtitles languages error: ${e.message}');
    }
    return ['en'];
  }
}
