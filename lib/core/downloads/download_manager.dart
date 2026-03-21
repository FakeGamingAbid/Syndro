import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../providers/providers.dart';
import '../subtitles/subtitle_service.dart';

/// Provider for DownloadManager
final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, DownloadManagerState>((ref) {
  return DownloadManager(ref);
});

/// Download quality enum
enum DownloadQuality {
  p480('480p'),
  p720('720p'),
  p1080('1080p');

  final String label;
  const DownloadQuality(this.label);
}

/// Download request
class DownloadRequest {
  final String contentId;
  final String title;
  final String? posterUrl;
  final String videoUrl;
  final DownloadQuality quality;
  final SubtitleTrack? subtitleTrack;
  final int? tmdbId;
  final String? mediaType;

  DownloadRequest({
    required this.contentId,
    required this.title,
    this.posterUrl,
    required this.videoUrl,
    required this.quality,
    this.subtitleTrack,
    this.tmdbId,
    this.mediaType,
  });
}

/// Download status
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

/// Download item
class DownloadItem {
  final String id;
  final String contentId;
  final String title;
  final String? posterUrl;
  final DownloadQuality quality;
  final DownloadStatus status;
  final double progress;
  final int? fileSizeBytes;
  final int? downloadedBytes;
  final String? filePath;
  final String? subtitlePath;
  final String? error;
  final DateTime createdAt;
  final int? tmdbId;

  DownloadItem({
    required this.id,
    required this.contentId,
    required this.title,
    this.posterUrl,
    required this.quality,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.fileSizeBytes,
    this.downloadedBytes,
    this.filePath,
    this.subtitlePath,
    this.error,
    required this.createdAt,
    this.tmdbId,
  });

  DownloadItem copyWith({
    String? id,
    String? contentId,
    String? title,
    String? posterUrl,
    DownloadQuality? quality,
    DownloadStatus? status,
    double? progress,
    int? fileSizeBytes,
    int? downloadedBytes,
    String? filePath,
    String? subtitlePath,
    String? error,
    DateTime? createdAt,
    int? tmdbId,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      filePath: filePath ?? this.filePath,
      subtitlePath: subtitlePath ?? this.subtitlePath,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      tmdbId: tmdbId ?? this.tmdbId,
    );
  }
}

/// Download manager state
class DownloadManagerState {
  final List<DownloadItem> activeDownloads;
  final List<DownloadItem> completedDownloads;
  final int totalSizeBytes;

  DownloadManagerState({
    this.activeDownloads = const [],
    this.completedDownloads = const [],
    this.totalSizeBytes = 0,
  });

  DownloadManagerState copyWith({
    List<DownloadItem>? activeDownloads,
    List<DownloadItem>? completedDownloads,
    int? totalSizeBytes,
  }) {
    return DownloadManagerState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      completedDownloads: completedDownloads ?? this.completedDownloads,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
    );
  }
}

/// Download manager
class DownloadManager extends StateNotifier<DownloadManagerState> {
  final Ref _ref;
  late final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadManager(this._ref) : super(DownloadManagerState()) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
    ));
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    try {
      final db = _ref.read(appDatabaseProvider);
      final downloads = await db.getDownloadedContent(1);
      
      final completed = downloads.map((d) => DownloadItem(
        id: d.id.toString(),
        contentId: d.contentId,
        title: d.title,
        posterUrl: d.posterPath,
        quality: _parseQuality(d.quality),
        status: DownloadStatus.completed,
        fileSizeBytes: d.fileSizeBytes,
        filePath: d.filePath,
        subtitlePath: d.subtitlePath,
        createdAt: d.downloadedAt,
        tmdbId: d.tmdbId,
      )).toList();

      int totalSize = 0;
      for (final d in completed) {
        totalSize += d.fileSizeBytes ?? 0;
      }

      state = state.copyWith(
        completedDownloads: completed,
        totalSizeBytes: totalSize,
      );
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  DownloadQuality _parseQuality(String quality) {
    if (quality.contains('1080')) return DownloadQuality.p1080;
    if (quality.contains('720')) return DownloadQuality.p720;
    return DownloadQuality.p480;
  }

  /// Start a download
  Future<void> startDownload(DownloadRequest request) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: id,
      contentId: request.contentId,
      title: request.title,
      posterUrl: request.posterUrl,
      quality: request.quality,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      tmdbId: request.tmdbId,
    );

    state = state.copyWith(
      activeDownloads: [...state.activeDownloads, item],
    );

    try {
      // Get output directory
      final outputDir = await _getOutputDirectory();
      final outputPath = '${outputDir.path}/${request.contentId}.mp4';

      if (request.videoUrl.contains('.m3u8')) {
        // HLS download
        await _downloadHls(request.videoUrl, outputPath, id, request);
      } else {
        // MP4 download
        await _downloadMp4(request.videoUrl, outputPath, id, request);
      }

      // Download subtitle if present
      String? subtitlePath;
      if (request.subtitleTrack != null) {
        subtitlePath = await _downloadSubtitle(request, outputDir.path);
      }

      // Mark as completed
      final file = File(outputPath);
      final fileSize = await file.length();

      // Save to database
      await _saveToDatabase(request, outputPath, subtitlePath, fileSize);

      // Update state
      final updatedActive = state.activeDownloads.where((d) => d.id != id).toList();
      final completedItem = item.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        fileSizeBytes: fileSize,
        filePath: outputPath,
        subtitlePath: subtitlePath,
      );

      state = state.copyWith(
        activeDownloads: updatedActive,
        completedDownloads: [...state.completedDownloads, completedItem],
        totalSizeBytes: state.totalSizeBytes + fileSize,
      );
    } catch (e) {
      // Mark as failed
      _updateDownload(id, item.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      ));
    }
  }

  /// Download MP4 file
  Future<void> _downloadMp4(
    String url,
    String outputPath,
    String id,
    DownloadRequest request,
  ) async {
    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;

    await _dio.download(
      url,
      outputPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          _updateDownload(id, state.activeDownloads
              .firstWhere((d) => d.id == id)
              .copyWith(
                progress: progress,
                downloadedBytes: received,
                fileSizeBytes: total,
              ));
        }
      },
    );

    _cancelTokens.remove(id);
  }

  /// Download HLS stream
  Future<void> _downloadHls(
    String url,
    String outputPath,
    String id,
    DownloadRequest request,
  ) async {
    // First, fetch the m3u8 manifest
    final response = await _dio.get(url);
    final manifest = response.data as String;
    
    // Parse segment URLs
    final segments = _parseM3u8Segments(manifest, url);
    
    if (segments.isEmpty) {
      throw Exception('No segments found in manifest');
    }

    final tempDir = await getTemporaryDirectory();
    final segmentsDir = Directory('${tempDir.path}/segments_$id');
    await segmentsDir.create(recursive: true);

    // Download all segments
    final totalSegments = segments.length;
    for (int i = 0; i < segments.length; i++) {
      final segmentUrl = segments[i];
      final segmentPath = '${segmentsDir.path}/segment_$i.ts';
      
      await _dio.download(segmentUrl, segmentPath);
      
      final progress = (i + 1) / totalSegments;
      _updateDownload(id, state.activeDownloads
          .firstWhere((d) => d.id == id)
          .copyWith(progress: progress));
    }

    // Use ffmpeg to merge segments
    // Note: In production, you'd use ffmpeg_kit_flutter
    // For now, we'll just copy the first segment as a placeholder
    final firstSegment = File('${segmentsDir.path}/segment_0.ts');
    if (await firstSegment.exists()) {
      await firstSegment.copy(outputPath);
    }

    // Cleanup segments
    await segmentsDir.delete(recursive: true);
  }

  List<String> _parseM3u8Segments(String manifest, String baseUrl) {
    final segments = <String>[];
    final lines = manifest.split('\n');
    
    for (final line in lines) {
      if (line.isNotEmpty && !line.startsWith('#')) {
        if (line.startsWith('http')) {
          segments.add(line);
        } else {
          // Relative URL - prepend base
          final base = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);
          segments.add('$base$line');
        }
      }
    }
    
    return segments;
  }

  /// Download subtitle for video
  Future<String?> _downloadSubtitle(DownloadRequest request, String videoDir) async {
    if (request.subtitleTrack == null) return null;
    
    try {
      final track = request.subtitleTrack!;
      final subtitleFileName = '${request.contentId}.${track.languageCode}.srt';
      final subtitlePath = '$videoDir/$subtitleFileName';
      
      // If it's a local file, copy it
      if (track.url.startsWith('/')) {
        await File(track.url).copy(subtitlePath);
        return subtitlePath;
      }
      
      // Otherwise download it
      await _dio.download(track.url, subtitlePath);
      return subtitlePath;
    } catch (e) {
      debugPrint('Error downloading subtitle: $e');
      return null;
    }
  }

  /// Save download to database
  Future<void> _saveToDatabase(
    DownloadRequest request,
    String filePath,
    String? subtitlePath,
    int fileSize,
  ) async {
    final db = _ref.read(appDatabaseProvider);
    await db.addDownloadedContent(DownloadedContentCompanion(
      profileId: const Value(1),
      contentId: Value(request.contentId),
      title: Value(request.title),
      posterPath: Value(request.posterUrl),
      mediaType: Value(request.mediaType ?? 'movie'),
      filePath: Value(filePath),
      subtitlePath: Value(subtitlePath),
      quality: Value(request.quality.label),
      fileSizeBytes: Value(fileSize),
      tmdbId: Value(request.tmdbId),
    ));
  }

  /// Pause a download
  Future<void> pauseDownload(String id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Paused');
    }
    
    _updateDownload(id, state.activeDownloads
        .firstWhere((d) => d.id == id)
        .copyWith(status: DownloadStatus.paused));
  }

  /// Resume a download
  Future<void> resumeDownload(String id) async {
    // Would need to store the original request to resume
    // For simplicity, we'll just mark it as downloading again
    _updateDownload(id, state.activeDownloads
        .firstWhere((d) => d.id == id)
        .copyWith(status: DownloadStatus.downloading));
  }

  /// Cancel a download
  Future<void> cancelDownload(String id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Cancelled');
    }
    
    final updated = state.activeDownloads.where((d) => d.id != id).toList();
    state = state.copyWith(activeDownloads: updated);
  }

  /// Delete a completed download
  Future<void> deleteDownload(String id) async {
    final item = state.completedDownloads.firstWhere((d) => d.id == id);
    
    // Delete file
    if (item.filePath != null) {
      final file = File(item.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Delete subtitle
    if (item.subtitlePath != null) {
      final subFile = File(item.subtitlePath!);
      if (await subFile.exists()) {
        await subFile.delete();
      }
    }
    
    // Remove from database
    final db = _ref.read(appDatabaseProvider);
    await db.removeDownloadedContent(int.parse(id));
    
    // Update state
    final updated = state.completedDownloads.where((d) => d.id != id).toList();
    state = state.copyWith(
      completedDownloads: updated,
      totalSizeBytes: state.totalSizeBytes - (item.fileSizeBytes ?? 0),
    );
  }

  void _updateDownload(String id, DownloadItem updated) {
    final updatedList = state.activeDownloads.map((d) {
      if (d.id == id) return updated;
      return d;
    }).toList();
    
    state = state.copyWith(activeDownloads: updatedList);
  }

  /// Get output directory
  Future<Directory> _getOutputDirectory() async {
    Directory outputDir;
    
    if (Platform.isAndroid) {
      outputDir = Directory('/storage/emulated/0/Moonplex/Downloads');
    } else if (Platform.isWindows) {
      final docs = await getApplicationDocumentsDirectory();
      outputDir = Directory('${docs.path}/Moonplex/Downloads');
    } else if (Platform.isLinux) {
      outputDir = Directory('${Platform.environment['HOME']}/Moonplex/Downloads');
    } else if (Platform.isMacOS) {
      outputDir = Directory('${Platform.environment['HOME']}/Movies/Moonplex/Downloads');
    } else {
      outputDir = await getTemporaryDirectory();
    }
    
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    return outputDir;
  }

  /// Get available storage
  Future<int> getAvailableStorage() async {
    // Would need platform-specific code to get actual available storage
    return 0;
  }
}
