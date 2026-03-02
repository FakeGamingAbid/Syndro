import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transfer.dart';

/// Provider for managing files received from command line arguments (right-click send)
final incomingFilesProvider =
    StateNotifierProvider<IncomingFilesNotifier, IncomingFilesState>((ref) {
  return IncomingFilesNotifier();
});

/// State for incoming files
class IncomingFilesState {
  final List<TransferItem> files;
  final bool hasFiles;
  final bool isProcessing;

  const IncomingFilesState({
    this.files = const [],
    this.hasFiles = false,
    this.isProcessing = false,
  });

  IncomingFilesState copyWith({
    List<TransferItem>? files,
    bool? hasFiles,
    bool? isProcessing,
  }) {
    return IncomingFilesState(
      files: files ?? this.files,
      hasFiles: hasFiles ?? this.hasFiles,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Notifier for managing incoming files state
class IncomingFilesNotifier extends StateNotifier<IncomingFilesState> {
  IncomingFilesNotifier() : super(const IncomingFilesState());

  /// Process file paths from command line arguments or Android share intents
  /// 
  /// On Android, paths may be content:// URIs that need special handling.
  /// On desktop, paths are regular file system paths.
  Future<void> setFilesFromPaths(List<String> paths) async {
    if (paths.isEmpty) return;

    state = state.copyWith(isProcessing: true);

    final items = <TransferItem>[];

    for (final path in paths) {
      try {
        // Skip Flutter/Dart internal arguments
        if (path.startsWith('--') || path.startsWith('-')) {
          continue;
        }

        // Handle Android content:// URIs
        if (path.startsWith('content://')) {
          debugPrint('📱 Processing Android content URI: $path');
          // For content URIs, we'll use the URI directly
          // The transfer service will handle reading from the content resolver
          final name = _extractNameFromContentUri(path);
          
          items.add(TransferItem(
            name: name,
            path: path,
            size: 0, // Size unknown for content URIs until read
            isDirectory: false,
          ));
          
          debugPrint('📁 Added content URI: $name');
          continue;
        }

        final file = File(path);
        final directory = Directory(path);

        if (await file.exists()) {
          final stat = await file.stat();
          final name = path.split(Platform.pathSeparator).last;
          
          items.add(TransferItem(
            name: name,
            path: path,
            size: stat.size,
            isDirectory: false,
          ));
          
          debugPrint('📁 Added file: $name (${_formatBytes(stat.size)})');
        } else if (await directory.exists()) {
          // Calculate folder size
          int folderSize = 0;
          int fileCount = 0;
          
          await for (final entity in directory.list(recursive: true)) {
            if (entity is File) {
              folderSize += await entity.length();
              fileCount++;
            }
          }

          final name = path.split(Platform.pathSeparator).last;
          
          items.add(TransferItem(
            name: name,
            path: path,
            size: folderSize,
            isDirectory: true,
          ));
          
          debugPrint('📂 Added folder: $name ($fileCount files, ${_formatBytes(folderSize)})');
        } else {
          debugPrint('⚠️ Path does not exist: $path');
        }
      } catch (e) {
        debugPrint('❌ Error processing path $path: $e');
      }
    }

    state = IncomingFilesState(
      files: items,
      hasFiles: items.isNotEmpty,
      isProcessing: false,
    );

    if (items.isNotEmpty) {
      debugPrint('✅ Loaded ${items.length} incoming file(s)');
    }
  }

  /// Extract a readable name from Android content URI
  String _extractNameFromContentUri(String uri) {
    // Try to extract from the last segment
    // e.g., content://media/external/images/media/123 -> media/123
    // or content://com.android.providers.media.documents/document/image%3A123
    try {
      final decoded = Uri.decodeComponent(uri);
      final segments = decoded.split('/');
      if (segments.isNotEmpty) {
        // Return last meaningful segment
        for (int i = segments.length - 1; i >= 0; i--) {
          if (segments[i].isNotEmpty && 
              !segments[i].startsWith('content:') &&
              segments[i] != 'document' &&
              segments[i] != 'media') {
            return segments[i];
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting name from URI: $e');
    }
    return 'shared_file';
  }

  /// Add more files to the existing list
  void addFiles(List<TransferItem> newFiles) {
    final updatedFiles = [...state.files, ...newFiles];
    state = state.copyWith(
      files: updatedFiles,
      hasFiles: updatedFiles.isNotEmpty,
    );
  }

  /// Set files directly (for Android share intents where we already have the info)
  void setFiles(List<TransferItem> files) {
    state = IncomingFilesState(
      files: files,
      hasFiles: files.isNotEmpty,
      isProcessing: false,
    );
    if (files.isNotEmpty) {
      debugPrint('✅ Set ${files.length} file(s) directly');
    }
  }

  /// Remove a file from the list
  void removeFile(TransferItem item) {
    final updatedFiles = state.files.where((f) => f.path != item.path).toList();
    state = state.copyWith(
      files: updatedFiles,
      hasFiles: updatedFiles.isNotEmpty,
    );
  }

  /// Clear all incoming files
  void clear() {
    state = const IncomingFilesState();
  }

  /// Get total size of all files
  int get totalSize => state.files.fold(0, (sum, item) => sum + item.size);

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
