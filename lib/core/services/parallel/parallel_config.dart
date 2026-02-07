import 'dart:io';

import 'package:flutter/foundation.dart';

/// Configuration for parallel chunk transfers
///
/// Automatically adjusts based on device capabilities
class ParallelConfig {
  /// Number of parallel connections
  final int connections;

  /// Chunk size in bytes
  final int chunkSize;

  /// Minimum file size to use parallel transfer (bytes)
  final int minFileSize;

  /// Whether parallel transfer is enabled
  final bool enabled;

  /// Whether this is for browser transfer
  final bool isBrowser;

  const ParallelConfig({
    required this.connections,
    required this.chunkSize,
    required this.minFileSize,
    this.enabled = true,
    this.isBrowser = false,
  });

  /// Default config for App-to-App transfers (OPTIMIZED)
  static const ParallelConfig appToApp = ParallelConfig(
    connections: 8,                   // Increased from 4
    chunkSize: 2 * 1024 * 1024,      // 2MB (increased from 1MB)
    minFileSize: 10 * 1024 * 1024,   // 10MB minimum
    enabled: true,
    isBrowser: false,
  );

  /// Default config for App-to-Browser transfers (OPTIMIZED)
  static const ParallelConfig appToBrowser = ParallelConfig(
    connections: 4,                   // Increased from 2
    chunkSize: 2 * 1024 * 1024,      // 2MB (increased from 1MB)
    minFileSize: 10 * 1024 * 1024,   // 10MB minimum
    enabled: true,
    isBrowser: true,
  );

  /// Conservative config for low-end devices (4GB RAM or less)
  static const ParallelConfig lowEnd = ParallelConfig(
    connections: 4,                   // Increased from 2
    chunkSize: 1 * 1024 * 1024,      // 1MB
    minFileSize: 20 * 1024 * 1024,   // 20MB minimum
    enabled: true,
    isBrowser: false,
  );

  /// Config for single connection (fallback)
  static const ParallelConfig single = ParallelConfig(
    connections: 1,
    chunkSize: 1 * 1024 * 1024,      // 1MB
    minFileSize: 0,
    enabled: false,
    isBrowser: false,
  );

  /// Auto-detect best config based on device
  static Future<ParallelConfig> autoDetect({bool isBrowser = false}) async {
    if (isBrowser) {
      return appToBrowser;
    }

    try {
      final ramGB = await _getDeviceRAMGB();

      if (ramGB <= 4) {
        debugPrint('📱 Low-end device detected ($ramGB GB RAM), using conservative config');
        return lowEnd;
      } else if (ramGB <= 8) {
        debugPrint('📱 Mid-range device detected ($ramGB GB RAM), using balanced config');
        return appToApp;
      } else {
        debugPrint('📱 High-end device detected ($ramGB GB RAM), using max performance config');
        return const ParallelConfig(
          connections: 12,                  // Increased from 6
          chunkSize: 4 * 1024 * 1024,      // 4MB (increased from 2MB)
          minFileSize: 10 * 1024 * 1024,
          enabled: true,
          isBrowser: false,
        );
      }
    } catch (e) {
      debugPrint('Could not detect device RAM, using default config: $e');
      return appToApp;
    }
  }

  /// Get device RAM in GB (approximate)
  static Future<int> _getDeviceRAMGB() async {
    try {
      if (Platform.isAndroid) {
        // Try to read from /proc/meminfo
        final file = File('/proc/meminfo');
        if (await file.exists()) {
          final content = await file.readAsString();
          final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(content);
          if (match != null) {
            final kb = int.parse(match.group(1)!);
            return (kb / 1024 / 1024).round(); // Convert to GB
          }
        }
      } else if (Platform.isWindows || Platform.isLinux) {
        // Desktop usually has more RAM
        if (Platform.isLinux) {
          final file = File('/proc/meminfo');
          if (await file.exists()) {
            final content = await file.readAsString();
            final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(content);
            if (match != null) {
              final kb = int.parse(match.group(1)!);
              return (kb / 1024 / 1024).round();
            }
          }
        }
        // Assume 16GB for desktop if can't detect
        return 16;
      }
    } catch (e) {
      debugPrint('Error detecting RAM: $e');
    }

    // Default assumption: 8GB
    return 8;
  }

  /// Check if file should use parallel transfer
  bool shouldUseParallel(int fileSize) {
    return enabled && fileSize >= minFileSize;
  }

  /// Calculate number of chunks for a file
  int calculateChunkCount(int fileSize) {
    return (fileSize / chunkSize).ceil();
  }

  /// Get chunk info for a specific chunk index
  ChunkInfo getChunkInfo(int chunkIndex, int fileSize) {
    final start = chunkIndex * chunkSize;
    final end = (start + chunkSize).clamp(0, fileSize);
    final size = end - start;

    return ChunkInfo(
      index: chunkIndex,
      start: start,
      end: end,
      size: size,
    );
  }

  /// Get all chunk infos for a file
  List<ChunkInfo> getAllChunks(int fileSize) {
    final count = calculateChunkCount(fileSize);
    return List.generate(count, (i) => getChunkInfo(i, fileSize));
  }

  /// Calculate max RAM usage
  int get maxRamUsage => connections * chunkSize * 2; // *2 for safety margin

  @override
  String toString() {
    return 'ParallelConfig(connections: $connections, chunkSize: ${chunkSize ~/ 1024}KB, '
        'minFileSize: ${minFileSize ~/ 1024 ~/ 1024}MB, enabled: $enabled)';
  }
}

/// Information about a single chunk
class ChunkInfo {
  final int index;
  final int start;
  final int end;
  final int size;

  const ChunkInfo({
    required this.index,
    required this.start,
    required this.end,
    required this.size,
  });

  @override
  String toString() => 'Chunk[$index]: $start-$end (${size}B)';
}

/// Transfer mode enum
enum TransferMode {
  /// Single connection (legacy)
  single,

  /// Parallel connections (fast)
  parallel,

  /// Auto-detect based on file size
  auto,
}
