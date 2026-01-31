import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/transfer_checkpoint.dart';

class CheckpointManager {
  static const String _checkpointsDir = 'checkpoints';

  // Save checkpoint to disk
  Future<void> saveCheckpoint(TransferCheckpoint checkpoint) async {
    try {
      final dir = await _getCheckpointsDirectory();
      final file = File(path.join(dir.path, '${checkpoint.transferId}.json'));
      
      final json = jsonEncode(checkpoint.toJson());
      await file.writeAsString(json);
    } catch (e) {
      print('Error saving checkpoint: $e');
    }
  }

  // Load checkpoint from disk
  Future<TransferCheckpoint?> loadCheckpoint(String transferId) async {
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
        await clearCheckpoint(transferId);
        return null;
      }
      
      return checkpoint;
    } catch (e) {
      print('Error loading checkpoint: $e');
      return null;
    }
  }

  // Clear checkpoint after transfer completion
  Future<void> clearCheckpoint(String transferId) async {
    try {
      final dir = await _getCheckpointsDirectory();
      final file = File(path.join(dir.path, '$transferId.json'));
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing checkpoint: $e');
    }
  }

  // Get all saved checkpoints
  Future<List<TransferCheckpoint>> getAllCheckpoints() async {
    try {
      final dir = await _getCheckpointsDirectory();
      
      if (!await dir.exists()) {
        return [];
      }
      
      final files = dir.listSync().whereType<File>();
      final checkpoints = <TransferCheckpoint>[];
      
      for (final file in files) {
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
          print('Error reading checkpoint file: $e');
        }
      }
      
      return checkpoints;
    } catch (e) {
      print('Error getting checkpoints: $e');
      return [];
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
      print('Error clearing all checkpoints: $e');
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
