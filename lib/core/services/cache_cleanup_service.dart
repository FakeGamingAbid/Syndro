import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for cleaning up cached files and temporary data
///
/// This service provides:
/// - Manual cache cleanup triggered by user
/// - Automatic cleanup on app startup
/// - Cache size reporting
class CacheCleanupService {
  /// Clear all temporary files and cache
  ///
  /// Returns the number of bytes freed
  static Future<int> clearAllCache() async {
    int totalFreed = 0;

    // Method 1: Use FilePicker's built-in clear
    try {
      await FilePicker.platform.clearTemporaryFiles();
      debugPrint('✅ FilePicker cache cleared');
    } catch (e) {
      debugPrint('FilePicker.clearTemporaryFiles failed: $e');
    }

    // Method 2: Clear app's temporary directory
    try {
      final tempDir = await getTemporaryDirectory();
      final freed = await _clearDirectory(tempDir);
      totalFreed += freed;
      debugPrint('✅ Temporary directory cleaned: $freed bytes');
    } catch (e) {
      debugPrint('Error clearing temp directory: $e');
    }

    // Method 3: Clear file_picker specific cache directory
    try {
      final cacheDir = await getTemporaryDirectory();
      final filePickerDir = Directory('${cacheDir.path}/file_picker');

      if (await filePickerDir.exists()) {
        final size = await _getDirectorySize(filePickerDir);
        await filePickerDir.delete(recursive: true);
        totalFreed += size;
        debugPrint('✅ FilePicker cache cleared: $size bytes');
      }

      // Also check for any file_picker related folders
      final cacheContents = cacheDir.listSync();
      for (final entity in cacheContents) {
        if (entity is Directory && entity.path.contains('file_picker')) {
          try {
            final size = await _getDirectorySize(entity);
            await entity.delete(recursive: true);
            totalFreed += size;
            debugPrint('✅ Cleared: ${entity.path}');
          } catch (e) {
            debugPrint('Failed to clear ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error in file_picker cache cleanup: $e');
    }

    // Method 4: Clear any web share related cache
    try {
      final cacheDir = await getTemporaryDirectory();
      final webShareDirs = ['web_share', 'share_server', 'receive_server'];
      
      for (final dirName in webShareDirs) {
        final webShareDir = Directory('${cacheDir.path}/$dirName');
        if (await webShareDir.exists()) {
          final size = await _getDirectorySize(webShareDir);
          await webShareDir.delete(recursive: true);
          totalFreed += size;
          debugPrint('✅ Cleared $dirName cache: $size bytes');
        }
      }
    } catch (e) {
      debugPrint('Error clearing web share cache: $e');
    }

    return totalFreed;
  }

  /// Get the current cache size in bytes
  static Future<int> getCacheSize() async {
    int totalSize = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      totalSize += await _getDirectorySize(tempDir);
    } catch (e) {
      debugPrint('Error getting temp dir size: $e');
    }

    return totalSize;
  }

  /// Clear a specific directory and return bytes freed
  static Future<int> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return 0;

    int freed = 0;
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            final size = await entity.length();
            await entity.delete();
            freed += size;
          } else if (entity is Directory) {
            // Skip system directories
            final name = entity.path.split('/').last;
            if (!name.startsWith('.')) {
              final size = await _getDirectorySize(entity);
              await entity.delete(recursive: true);
              freed += size;
            }
          }
        } catch (e) {
          // Skip files we can't delete
          debugPrint('Could not delete ${entity.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error listing directory: $e');
    }
    return freed;
  }

  /// Get size of a directory recursively
  static Future<int> _getDirectorySize(Directory dir) async {
    if (!await dir.exists()) return 0;

    int size = 0;
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        try {
          if (entity is File) {
            size += await entity.length();
          }
        } catch (e) {
          // Skip files we can't access
        }
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return size;
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
