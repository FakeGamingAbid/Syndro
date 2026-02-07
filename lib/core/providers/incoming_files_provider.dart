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

  /// Process file paths from command line arguments
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

  /// Add more files to the existing list
  void addFiles(List<TransferItem> newFiles) {
    final updatedFiles = [...state.files, ...newFiles];
    state = state.copyWith(
      files: updatedFiles,
      hasFiles: updatedFiles.isNotEmpty,
    );
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
