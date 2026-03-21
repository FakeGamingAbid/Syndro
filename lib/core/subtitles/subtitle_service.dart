import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../providers/providers.dart';
import 'opensubtitles_service.dart';

/// Provider for SubtitleService
final subtitleServiceProvider = Provider<SubtitleService>((ref) {
  return SubtitleService(ref);
});

/// Subtitle source enum
enum SubtitleSource {
  stream,       // Embedded in video stream
  provider,     // From CS3 provider
  opensubtitles, // From OpenSubtitles API
}

/// Subtitle format enum
enum SubtitleFormat {
  vtt,
  srt,
  ass,
  unknown,
}

/// Subtitle track model
class SubtitleTrack {
  final String language;
  final String languageCode;
  final String url;
  final SubtitleFormat format;
  final SubtitleSource source;
  final String label;
  final String? fileId; // For OpenSubtitles

  SubtitleTrack({
    required this.language,
    required this.languageCode,
    required this.url,
    required this.format,
    required this.source,
    required this.label,
    this.fileId,
  });

  SubtitleTrack copyWith({
    String? language,
    String? languageCode,
    String? url,
    SubtitleFormat? format,
    SubtitleSource? source,
    String? label,
    String? fileId,
  }) {
    return SubtitleTrack(
      language: language ?? this.language,
      languageCode: languageCode ?? this.languageCode,
      url: url ?? this.url,
      format: format ?? this.format,
      source: source ?? this.source,
      label: label ?? this.label,
      fileId: fileId ?? this.fileId,
    );
  }
}

/// Subtitle track list with auto-selection logic
class SubtitleTrackList {
  final List<SubtitleTrack> tracks;
  final SubtitleTrack? defaultTrack;
  final bool hasEmbedded;
  final bool hasProvider;
  final bool hasOpenSubtitles;

  SubtitleTrackList({
    required this.tracks,
    this.defaultTrack,
    this.hasEmbedded = false,
    this.hasProvider = false,
    this.hasOpenSubtitles = false,
  });

  bool get isEmpty => tracks.isEmpty;
  bool get isNotEmpty => tracks.isNotEmpty;

  factory SubtitleTrackList.empty() {
    return SubtitleTrackList(tracks: []);
  }
}

/// Subtitle service - main orchestrator for three-tier subtitle resolution
class SubtitleService {
  final Ref _ref;
  late final Dio _dio;
  late final OpenSubtitlesService _openSubtitlesService;

  SubtitleService(this._ref) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _openSubtitlesService = _ref.read(opensubtitlesServiceProvider);
  }

  /// Resolve subtitles using three-tier priority system
  /// 
  /// Tier 1: Embedded in stream (handled automatically by media_kit)
  /// Tier 2: Provider subtitle URLs  
  /// Tier 3: OpenSubtitles API fallback
  Future<SubtitleTrackList> resolveSubtitles({
    /// The video link URL from provider
    String? videoUrl,
    /// Subtitle URLs from CS3 provider
    List<ProviderSubtitle>? providerSubtitles,
    /// IMDB ID for OpenSubtitles search
    String? imdbId,
    /// Preferred language code (e.g., "en", "hi")
    String? preferredLanguage,
  }) async {
    final tracks = <SubtitleTrack>[];
    bool hasEmbedded = false;
    bool hasProvider = false;
    bool hasOpenSubtitles = false;

    // Get user preferences
    final prefs = await _getUserPreferences();
    final lang = preferredLanguage ?? prefs?.preferredLanguage ?? 'en';

    // Tier 1: Embedded tracks are handled automatically by media_kit
    // We mark this as available if we have a video URL
    if (videoUrl != null && videoUrl.isNotEmpty) {
      hasEmbedded = true;
    }

    // Tier 2: Process provider subtitle URLs
    if (providerSubtitles != null && providerSubtitles.isNotEmpty) {
      for (final sub in providerSubtitles) {
        try {
          // Download to cache if remote URL
          String localPath = sub.url;
          if (sub.url.startsWith('http')) {
            localPath = await _downloadToCache(sub.url, sub.languageCode);
          }

          final format = _parseFormat(sub.url);
          tracks.add(SubtitleTrack(
            language: _languageName(sub.languageCode),
            languageCode: sub.languageCode,
            url: localPath,
            format: format,
            source: SubtitleSource.provider,
            label: buildTrackLabel(
              _languageName(sub.languageCode),
              SubtitleSource.provider,
              format,
            ),
          ));
          hasProvider = true;
        } catch (e) {
          debugPrint('Error processing provider subtitle: $e');
        }
      }
    }

    // Tier 3: OpenSubtitles API fallback (only if no provider subtitles)
    if (tracks.isEmpty && imdbId != null && imdbId.isNotEmpty) {
      try {
        final results = await _openSubtitlesService.search(imdbId, lang);
        if (results.isNotEmpty) {
          // Get download URL for best result
          final best = results.first;
          final downloadUrl = await _openSubtitlesService.getDownloadUrl(best.fileId);
          
          if (downloadUrl != null) {
            final filename = '${imdbId}_${lang}_${best.fileId}.srt';
            final localPath = await _openSubtitlesService.downloadToCache(
              downloadUrl, 
              filename,
            );

            tracks.add(SubtitleTrack(
              language: best.language,
              languageCode: best.languageCode,
              url: localPath,
              format: SubtitleFormat.srt,
              source: SubtitleSource.opensubtitles,
              label: buildTrackLabel(
                best.language,
                SubtitleSource.opensubtitles,
                SubtitleFormat.srt,
              ),
              fileId: best.fileId,
            ));
            hasOpenSubtitles = true;
          }
        }
      } catch (e) {
        debugPrint('Error fetching OpenSubtitles: $e');
      }
    }

    // Auto-select best track
    SubtitleTrack? defaultTrack;
    if (tracks.isNotEmpty) {
      defaultTrack = _selectDefaultTrack(tracks, lang);
    }

    return SubtitleTrackList(
      tracks: tracks,
      defaultTrack: defaultTrack,
      hasEmbedded: hasEmbedded,
      hasProvider: hasProvider,
      hasOpenSubtitles: hasOpenSubtitles,
    );
  }

  /// Build human-readable label with source tag
  String buildTrackLabel(
    String language, 
    SubtitleSource source, 
    SubtitleFormat format,
  ) {
    final sourceTag = switch (source) {
      SubtitleSource.stream => 'Stream',
      SubtitleSource.provider => 'Provider',
      SubtitleSource.opensubtitles => 'OpenSubtitles',
    };

    final formatStr = format == SubtitleFormat.ass ? ' — ASS' : '';
    return '$language ($sourceTag)$formatStr';
  }

  /// Get user subtitle preferences from database
  Future<SubtitlePreference?> _getUserPreferences() async {
    try {
      final db = _ref.read(appDatabaseProvider);
      // Get active profile and its preferences
      // This would typically come from a profile provider
      return await db.getSubtitlePreferences(1); // Default profile ID
    } catch (e) {
      debugPrint('Error getting subtitle preferences: $e');
      return null;
    }
  }

  /// Select default track based on user preferences
  SubtitleTrack? _selectDefaultTrack(List<SubtitleTrack> tracks, String preferredLang) {
    // First try exact match
    final exact = tracks.where(
      (t) => t.languageCode.toLowerCase() == preferredLang.toLowerCase(),
    );
    if (exact.isNotEmpty) return exact.first;

    // Try English fallback
    final english = tracks.where(
      (t) => t.languageCode.toLowerCase() == 'en',
    );
    if (english.isNotEmpty) return english.first;

    // Return first available
    return tracks.first;
  }

  /// Download subtitle file to cache
  Future<String> _downloadToCache(String url, String languageCode) async {
    final cacheDir = await _getSubtitleCacheDir();
    final filename = '${DateTime.now().millisecondsSinceEpoch}_$languageCode.srt';
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
      final cachePath = '${Platform.environment['HOME']}/Library/Caches/Moonplex/subtitles';
      cacheDir = Directory(cachePath);
    } else {
      cacheDir = await getTemporaryDirectory();
    }

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Parse subtitle format from URL
  SubtitleFormat _parseFormat(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.vtt')) return SubtitleFormat.vtt;
    if (lower.endsWith('.srt')) return SubtitleFormat.srt;
    if (lower.endsWith('.ass') || lower.endsWith('.ssa')) return SubtitleFormat.ass;
    return SubtitleFormat.unknown;
  }

  /// Get language name from code
  String _languageName(String code) {
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

  /// Clear subtitle cache
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getSubtitleCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing subtitle cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getSubtitleCacheDir();
      if (!await cacheDir.exists()) return 0;

      int size = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    } catch (e) {
      return 0;
    }
  }
}

/// Provider subtitle model (from CS3 provider)
class ProviderSubtitle {
  final String url;
  final String languageCode;
  final String? language;

  ProviderSubtitle({
    required this.url,
    required this.languageCode,
    this.language,
  });
}
