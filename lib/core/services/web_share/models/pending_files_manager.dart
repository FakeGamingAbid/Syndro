import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'received_file.dart';

/// Manages pending files that have been received but not yet saved
class PendingFilesManager {
  final List<ReceivedFile> _pendingFiles = [];
  String? _tempDirectory;
  String? _finalDirectory;

  // Stream controller for file list updates
  final StreamController<List<ReceivedFile>> _filesController =
      StreamController<List<ReceivedFile>>.broadcast();

  // Stream controller for individual file events
  final StreamController<ReceivedFile> _fileEventController =
      StreamController<ReceivedFile>.broadcast();

  /// Stream of pending files list updates
  Stream<List<ReceivedFile>> get filesStream => _filesController.stream;

  /// Stream of individual file events (added, saved, discarded)
  Stream<ReceivedFile> get fileEventStream => _fileEventController.stream;

  /// Get current list of pending files
  List<ReceivedFile> get pendingFiles => List.unmodifiable(_pendingFiles);

  /// Get only files that are pending (not yet saved/discarded)
  List<ReceivedFile> get unsavedFiles =>
      _pendingFiles.where((f) => f.status == FileReceiveStatus.pending).toList();

  /// Get saved files
  List<ReceivedFile> get savedFiles =>
      _pendingFiles.where((f) => f.status == FileReceiveStatus.saved).toList();

  /// Check if there are any pending files
  bool get hasPendingFiles => unsavedFiles.isNotEmpty;

  /// Get count of pending files
  int get pendingCount => unsavedFiles.length;

  /// Get total count of all files
  int get totalCount => _pendingFiles.length;

  /// Initialize with directories
  Future<void> initialize({
    required String tempDirectory,
    required String finalDirectory,
  }) async {
    _tempDirectory = tempDirectory;
    _finalDirectory = finalDirectory;

    // Ensure temp directory exists
    final tempDir = Directory(tempDirectory);
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }

    // Ensure final directory exists
    final finalDir = Directory(finalDirectory);
    if (!await finalDir.exists()) {
      await finalDir.create(recursive: true);
    }

    debugPrint('📁 PendingFilesManager initialized');
    debugPrint('   Temp: $tempDirectory');
    debugPrint('   Final: $finalDirectory');
  }

  /// Get temp directory path
  String get tempDirectory => _tempDirectory ?? '';

  /// Get final directory path
  String get finalDirectory => _finalDirectory ?? '';

  /// Add a new pending file
  void addFile(ReceivedFile file) {
    _pendingFiles.add(file);
    _notifyListeners();
    _fileEventController.add(file);
    debugPrint('📥 Added pending file: ${file.name}');
  }

  /// Save a single file to final destination
  Future<bool> saveFile(ReceivedFile file) async {
    if (!file.canSave) {
      debugPrint('⚠️ Cannot save file: ${file.name} (status: ${file.status})');
      return false;
    }

    if (_finalDirectory == null) {
      debugPrint('❌ Final directory not set');
      return false;
    }

    try {
      file.status = FileReceiveStatus.saving;
      _notifyListeners();

      final tempFile = File(file.tempPath);
      if (!await tempFile.exists()) {
        throw Exception('Temp file does not exist');
      }

      // Generate final path
      final finalPath = path.join(_finalDirectory!, file.name);
      file.finalPath = await _getUniqueFilePath(finalPath);

      // Copy to final location
      await tempFile.copy(file.finalPath!);

      // Delete temp file
      await tempFile.delete();

      file.status = FileReceiveStatus.saved;
      _notifyListeners();
      _fileEventController.add(file);

      debugPrint('✅ Saved file: ${file.name} → ${file.finalPath}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving file ${file.name}: $e');
      file.status = FileReceiveStatus.error;
      file.errorMessage = e.toString();
      _notifyListeners();
      return false;
    }
  }

  /// Save all pending files
  Future<SaveAllResult> saveAllFiles() async {
    final filesToSave = unsavedFiles;
    int successCount = 0;
    int failCount = 0;

    for (final file in filesToSave) {
      final success = await saveFile(file);
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    return SaveAllResult(
      totalFiles: filesToSave.length,
      successCount: successCount,
      failCount: failCount,
    );
  }

  /// Discard a single file (delete from temp)
  Future<bool> discardFile(ReceivedFile file) async {
    if (!file.canDiscard) {
      debugPrint('⚠️ Cannot discard file: ${file.name} (status: ${file.status})');
      return false;
    }

    try {
      final tempFile = File(file.tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      file.status = FileReceiveStatus.discarded;
      _notifyListeners();
      _fileEventController.add(file);

      debugPrint('🗑️ Discarded file: ${file.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Error discarding file ${file.name}: $e');
      return false;
    }
  }

  /// Discard all pending files
  Future<void> discardAllFiles() async {
    final filesToDiscard = unsavedFiles;
    for (final file in filesToDiscard) {
      await discardFile(file);
    }
  }

  /// Remove a file from the list (after save or discard)
  void removeFile(ReceivedFile file) {
    _pendingFiles.remove(file);
    _notifyListeners();
  }

  /// Clear all files and clean up temp directory
  Future<void> clearAll() async {
    // Delete all temp files
    for (final file in _pendingFiles) {
      try {
        final tempFile = File(file.tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }

    _pendingFiles.clear();
    _notifyListeners();
  }

  /// Get unique file path (add number suffix if exists)
  Future<String> _getUniqueFilePath(String filePath) async {
    var file = File(filePath);
    if (!await file.exists()) {
      return filePath;
    }

    final dir = path.dirname(filePath);
    final baseName = path.basenameWithoutExtension(filePath);
    final ext = path.extension(filePath);

    int counter = 1;
    while (await file.exists()) {
      final newPath = path.join(dir, '$baseName ($counter)$ext');
      file = File(newPath);
      counter++;
    }

    return file.path;
  }

  void _notifyListeners() {
    _filesController.add(List.unmodifiable(_pendingFiles));
  }

  /// Dispose resources
  Future<void> dispose() async {
    await clearAll();
    await _filesController.close();
    await _fileEventController.close();
  }
}

/// Result of saving all files
class SaveAllResult {
  final int totalFiles;
  final int successCount;
  final int failCount;

  SaveAllResult({
    required this.totalFiles,
    required this.successCount,
    required this.failCount,
  });

  bool get allSuccessful => failCount == 0;
  bool get allFailed => successCount == 0;
  bool get partial => successCount > 0 && failCount > 0;
}
