import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/transfer_checkpoint.dart';

/// Manages transfer checkpoints (save/load/clear) for resume-on-failure.
///
/// **Important**: The file-based locking mechanism (`_fileLocks`) only provides
/// mutual exclusion within a **single process**. If multiple Syndro instances
/// are running concurrently, checkpoint files may be corrupted. Ensure only
/// one instance of Syndro runs at a time, or use a cross-process lock
/// (e.g. named mutex on Windows) if multi-instance support is needed.
class CheckpointManager {
  static const String _checkpointsDir = 'checkpoints';

  // FIX (Bug #1): File-based locking for cross-process safety
  final Map<String, bool> _fileLocks = {};

  Future<bool> _acquireLock(String transferId) async {
    // Check in-process lock first
    if (_fileLocks[transferId] == true) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_fileLocks[transferId] == true) {
        return false;
      }
    }

    // Try to acquire file-based lock for cross-process safety
    try {
      final dir = await _getCheckpointsDirectory();
      final lockFile = File(path.join(dir.path, '$transferId.lock'));

      // Try to create lock file exclusively
      if (await lockFile.exists()) {
        // Check if lock is stale (older than 30 seconds)
        final stat = await lockFile.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age.inSeconds > 30) {
          // Stale lock, remove it
          await lockFile.delete();
        } else {
          return false; // Lock held by another process
        }
      }

      // Create lock file
      await lockFile.writeAsString(DateTime.now().toIso8601String());
      _fileLocks[transferId] = true;
      return true;
    } catch (e) {
      debugPrint('⚠️ Lock acquisition error: $e');
      return false;
    }
  }

  Future<void> _releaseLock(String transferId) async {
    _fileLocks.remove(transferId);

    // Remove file-based lock
    try {
      final dir = await _getCheckpointsDirectory();
      final lockFile = File(path.join(dir.path, '$transferId.lock'));
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
    } catch (e) {
      debugPrint('⚠️ Lock release error: $e');
    }
  }

  // Save checkpoint to disk
  Future<void> saveCheckpoint(TransferCheckpoint checkpoint) async {
    final acquired = await _acquireLock(checkpoint.transferId);
    if (!acquired) {
      debugPrint('⚠️ Could not acquire lock for checkpoint: ${checkpoint.transferId}');
      return;
    }

    try {
      final dir = await _getCheckpointsDirectory();
      final file = File(path.join(dir.path, '${checkpoint.transferId}.json'));

      final json = jsonEncode(checkpoint.toJson());
      await file.writeAsString(json);
    } catch (e) {
      // FIX: Use debugPrint instead of print
      debugPrint('Error saving checkpoint: $e');
    } finally {
      await _releaseLock(checkpoint.transferId);
    }
  }

  // Load checkpoint from disk
  Future<TransferCheckpoint?> loadCheckpoint(String transferId) async {
    final acquired = await _acquireLock(transferId);
    if (!acquired) {
      debugPrint('⚠️ Could not acquire lock for checkpoint: $transferId');
      return null;
    }

    try {
      final dir = await _getCheckpointsDirectory();
      final file = File(path.join(dir.path, '$transferId.json'));

      if (!await file.exists()) {
        return null;
      }

      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      final checkpoint = TransferCheckpoint.fromJson(json);

      // Check if checkpoint is still valid
      if (!checkpoint.isValid) {
        // Release lock before calling clearCheckpoint to avoid deadlock
        await _releaseLock(transferId);
        await clearCheckpoint(transferId);
        return null;
      }

      return checkpoint;
    } catch (e) {
      // FIX: Use debugPrint instead of print
      debugPrint('Error loading checkpoint: $e');
      return null;
    } finally {
      await _releaseLock(transferId);
    }
  }

  // Clear checkpoint after transfer completion
  Future<void> clearCheckpoint(String transferId) async {
    final acquired = await _acquireLock(transferId);
    if (!acquired) {
      debugPrint('⚠️ Could not acquire lock for clearing checkpoint: $transferId');
      // Try to delete anyway as this is cleanup
    }

    try {
      final dir = await _getCheckpointsDirectory();
      final file = File(path.join(dir.path, '$transferId.json'));

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // FIX: Use debugPrint instead of print
      debugPrint('Error clearing checkpoint: $e');
    } finally {
      if (acquired) {
        await _releaseLock(transferId);
      }
    }
  }

  // FIX (Bug #19): Get checkpoints with pagination to avoid memory spike
  Future<List<TransferCheckpoint>> getAllCheckpoints({
    int? limit,
    int offset = 0,
  }) async {
    try {
      final dir = await _getCheckpointsDirectory();

      if (!await dir.exists()) {
        return [];
      }

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json')) // Skip .lock files
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      // Apply pagination
      final startIndex = offset;
      final endIndex = limit != null ? (offset + limit).clamp(0, files.length) : files.length;
      final paginatedFiles = files.sublist(
        startIndex.clamp(0, files.length),
        endIndex,
      );

      final checkpoints = <TransferCheckpoint>[];

      for (final file in paginatedFiles) {
        try {
          final contents = await file.readAsString();
          final json = jsonDecode(contents) as Map<String, dynamic>;
          final checkpoint = TransferCheckpoint.fromJson(json);

          if (checkpoint.isValid) {
            checkpoints.add(checkpoint);
          } else {
            // Delete invalid checkpoint
            await file.delete();
          }
        } catch (e) {
          // FIX: Use debugPrint instead of print
          debugPrint('Error reading checkpoint file: $e');
        }
      }

      return checkpoints;
    } catch (e) {
      // FIX: Use debugPrint instead of print
      debugPrint('Error getting checkpoints: $e');
      return [];
    }
  }

  // Get total checkpoint count (for pagination)
  Future<int> getCheckpointCount() async {
    try {
      final dir = await _getCheckpointsDirectory();
      if (!await dir.exists()) return 0;

      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .length;
    } catch (e) {
      debugPrint('Error getting checkpoint count: $e');
      return 0;
    }
  }

  // Clear all checkpoints
  Future<void> clearAllCheckpoints() async {
    try {
      final dir = await _getCheckpointsDirectory();

      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // FIX: Use debugPrint instead of print
      debugPrint('Error clearing all checkpoints: $e');
    }
  }

  Future<Directory> _getCheckpointsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final checkpointsDir = Directory(path.join(appDir.path, _checkpointsDir));

    if (!await checkpointsDir.exists()) {
      await checkpointsDir.create(recursive: true);
    }

    return checkpointsDir;
  }
}
